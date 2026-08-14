import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const EXPECTED_SECRET_SHA256 = "4283c7f384e59f22cde887042e7c6708da4c9d076339c6f63fdecb9fb3b631a5";
const BUCKET = "payment-receipts";
const MAX_BYTES = 20 * 1024 * 1024;
const ALLOWED_TYPES = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/webp",
]);
const ALLOWED_EXTENSIONS = new Set(["pdf", "jpg", "jpeg", "png", "webp"]);

type JsonMap = Record<string, unknown>;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function serviceKey(): string {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, string>;
      return parsed.default ?? Object.values(parsed)[0] ?? "";
    } catch (_) {}
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function safeName(value: string): string {
  const clean = value
    .trim()
    .replace(/[\\/:*?"<>|]/g, "_")
    .replace(/\s+/g, " ")
    .replace(/^\.+|\.+$/g, "")
    .slice(0, 180);
  return clean || "receipt";
}

function extension(fileName: string): string {
  const dot = fileName.lastIndexOf(".");
  return dot >= 0 && dot < fileName.length - 1
    ? fileName.slice(dot + 1).toLowerCase()
    : "";
}

function decodeBase64(raw: string): Uint8Array {
  const value = raw.includes(",") ? raw.slice(raw.indexOf(",") + 1) : raw;
  const binary = atob(value.replace(/\s+/g, ""));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const suppliedSecret = request.headers.get("x-assistant-secret") ?? "";
    if (!suppliedSecret || await sha256(suppliedSecret) !== EXPECTED_SECRET_SHA256) {
      return json({ error: "Unauthorized" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const secret = serviceKey();
    if (!supabaseUrl || !secret) return json({ error: "Service not configured" }, 500);

    const admin = createClient(supabaseUrl, secret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const body = await request.json() as JsonMap;
    const action = String(body.action ?? "").trim();

    if (action === "ping") return json({ ok: true, service: "assistant-payment-receipts" });

    if (action === "upload") {
      const paymentId = String(body.payment_id ?? "").trim();
      const originalName = safeName(String(body.file_name ?? ""));
      const contentType = String(body.content_type ?? "").trim().toLowerCase();
      const fileBase64 = String(body.file_base64 ?? "").trim();
      const ext = extension(originalName);

      if (!paymentId) return json({ error: "payment_id is required" }, 400);
      if (!fileBase64) return json({ error: "file_base64 is required" }, 400);
      if (!ALLOWED_TYPES.has(contentType)) return json({ error: "Unsupported content type" }, 400);
      if (!ALLOWED_EXTENSIONS.has(ext)) return json({ error: "Unsupported file extension" }, 400);

      let bytes: Uint8Array;
      try {
        bytes = decodeBase64(fileBase64);
      } catch (_) {
        return json({ error: "Invalid base64" }, 400);
      }
      if (!bytes.length) return json({ error: "File is empty" }, 400);
      if (bytes.length > MAX_BYTES) return json({ error: "File exceeds 20 MB" }, 413);

      const { data: payment, error: paymentError } = await admin
        .from("payments")
        .select("id,employee_id,company_id,deleted_at")
        .eq("id", paymentId)
        .maybeSingle();
      if (paymentError) throw paymentError;
      if (!payment) return json({ error: "Payment not found" }, 404);
      if (payment.deleted_at) return json({ error: "Payment is deleted" }, 409);

      const storageName = safeName(originalName).replace(/\s+/g, "_");
      const filePath = `${payment.employee_id}/${payment.id}/${Date.now()}_assistant_${crypto.randomUUID().slice(0, 8)}_${storageName}`;
      const { error: uploadError } = await admin.storage.from(BUCKET).upload(filePath, bytes, {
        contentType,
        cacheControl: "3600",
        upsert: false,
      });
      if (uploadError) throw uploadError;

      const { data: receipt, error: insertError } = await admin
        .from("payment_receipts")
        .insert({
          payment_id: payment.id,
          employee_id: payment.employee_id,
          company_id: payment.company_id,
          file_name: originalName,
          file_path: filePath,
          content_type: contentType,
          upload_source: "assistant",
        })
        .select("id,payment_id,employee_id,company_id,file_name,file_path,content_type,created_at,upload_source")
        .single();
      if (insertError) {
        await admin.storage.from(BUCKET).remove([filePath]);
        throw insertError;
      }
      return json({ ok: true, receipt }, 201);
    }

    if (action === "signed_download") {
      const receiptId = String(body.receipt_id ?? "").trim();
      if (!receiptId) return json({ error: "receipt_id is required" }, 400);
      const { data: receipt, error: receiptError } = await admin
        .from("payment_receipts")
        .select("id,payment_id,employee_id,company_id,file_name,file_path,content_type,created_at,upload_source")
        .eq("id", receiptId)
        .maybeSingle();
      if (receiptError) throw receiptError;
      if (!receipt) return json({ error: "Receipt not found" }, 404);

      const downloadName = safeName(receipt.file_name || "receipt");
      const { data: signed, error: signedError } = await admin.storage
        .from(BUCKET)
        .createSignedUrl(receipt.file_path, 300, { download: downloadName });
      if (signedError) throw signedError;
      return json({
        ok: true,
        url: signed.signedUrl,
        file_name: downloadName,
        content_type: receipt.content_type,
        payment_id: receipt.payment_id,
        employee_id: receipt.employee_id,
        company_id: receipt.company_id,
      });
    }

    return json({ error: "Unsupported action" }, 400);
  } catch (error) {
    console.error("assistant payment receipts failed", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
