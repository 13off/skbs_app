import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.110.5";

const BUCKET = "payment-receipts";
const MAX_BYTES = 20 * 1024 * 1024;
const MAX_REQUEST_BYTES = Math.ceil(MAX_BYTES * 4 / 3) + 128 * 1024;
const ALLOWED_TYPES = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/webp",
]);
const ALLOWED_EXTENSIONS = new Set(["pdf", "jpg", "jpeg", "png", "webp"]);
const SECRET_CONFIG_NAME = "assistant_payment_receipts";
let cachedSecretSha256 = "";

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
    } catch (_) {
      // Fall back to the legacy service-role secret below.
    }
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

function isSha256(value: string): boolean {
  return /^[0-9a-f]{64}$/.test(value);
}

async function configuredSecretSha256(admin: SupabaseClient): Promise<string> {
  const fromEnvironment = Deno.env.get(
    "ASSISTANT_PAYMENT_RECEIPTS_SECRET_SHA256",
  )?.trim().toLowerCase() ?? "";
  if (isSha256(fromEnvironment)) return fromEnvironment;
  if (isSha256(cachedSecretSha256)) return cachedSecretSha256;

  const { data, error } = await admin
    .from("edge_auth_secret_hashes")
    .select("secret_sha256")
    .eq("name", SECRET_CONFIG_NAME)
    .maybeSingle();
  if (error) throw error;

  const fromDatabase = String(data?.secret_sha256 ?? "").trim().toLowerCase();
  if (isSha256(fromDatabase)) cachedSecretSha256 = fromDatabase;
  return cachedSecretSha256;
}

function sameText(first: string, second: string): boolean {
  if (first.length !== second.length) return false;
  let difference = 0;
  for (let index = 0; index < first.length; index += 1) {
    difference |= first.charCodeAt(index) ^ second.charCodeAt(index);
  }
  return difference === 0;
}

function safeName(value: string): string {
  const clean = value
    .trim()
    .normalize("NFKC")
    // deno-lint-ignore no-control-regex -- Strip control bytes from filenames.
    .replace(/[\u0000-\u001f\u007f]+/g, "_")
    .replace(/[\\/:*?"<>|]/g, "_")
    .replace(/\s+/g, " ")
    .replace(/^\.+|\.+$/g, "")
    .slice(0, 180);
  return clean || "receipt";
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
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

function matchesFileSignature(
  bytes: Uint8Array,
  contentType: string,
  ext: string,
): boolean {
  if (contentType === "application/pdf" && ext === "pdf") {
    return bytes.length >= 5 &&
      String.fromCharCode(...bytes.slice(0, 5)) === "%PDF-";
  }
  if (contentType === "image/jpeg" && ["jpg", "jpeg"].includes(ext)) {
    return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
      bytes[2] === 0xff;
  }
  if (contentType === "image/png" && ext === "png") {
    return bytes.length >= 8 &&
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
        .every((value, index) => bytes[index] === value);
  }
  if (contentType === "image/webp" && ext === "webp") {
    return bytes.length >= 12 &&
      String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
  }
  return false;
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const declaredLength = Number(request.headers.get("content-length") ?? 0);
    if (Number.isFinite(declaredLength) && declaredLength > MAX_REQUEST_BYTES) {
      return json({ error: "Request is too large" }, 413);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const secret = serviceKey();
    if (!supabaseUrl || !secret) {
      return json({ error: "Service not configured" }, 500);
    }

    const admin = createClient(supabaseUrl, secret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const expectedSecretSha256 = await configuredSecretSha256(admin);
    const suppliedSecret = request.headers.get("x-assistant-secret") ?? "";
    if (
      !expectedSecretSha256 || !suppliedSecret ||
      !sameText(await sha256(suppliedSecret), expectedSecretSha256)
    ) {
      return json({ error: "Unauthorized" }, 401);
    }

    const rawBody = await request.text();
    if (!rawBody || rawBody.length > MAX_REQUEST_BYTES) {
      return json({ error: "Request is too large" }, 413);
    }
    let body: JsonMap;
    try {
      body = JSON.parse(rawBody) as JsonMap;
    } catch (_) {
      return json({ error: "Invalid JSON" }, 400);
    }
    const action = String(body.action ?? "").trim();

    if (action === "ping") {
      return json({ ok: true, service: "assistant-payment-receipts" });
    }

    if (action === "upload") {
      const paymentId = String(body.payment_id ?? "").trim();
      const originalName = safeName(String(body.file_name ?? ""));
      const contentType = String(body.content_type ?? "").trim().toLowerCase();
      const fileBase64 = String(body.file_base64 ?? "").trim();
      const ext = extension(originalName);

      if (!isUuid(paymentId)) {
        return json({ error: "payment_id must be a UUID" }, 400);
      }
      if (!fileBase64) return json({ error: "file_base64 is required" }, 400);
      if (!ALLOWED_TYPES.has(contentType)) {
        return json({ error: "Unsupported content type" }, 400);
      }
      if (!ALLOWED_EXTENSIONS.has(ext)) {
        return json({ error: "Unsupported file extension" }, 400);
      }

      let bytes: Uint8Array;
      try {
        bytes = decodeBase64(fileBase64);
      } catch (_) {
        return json({ error: "Invalid base64" }, 400);
      }
      if (!bytes.length) return json({ error: "File is empty" }, 400);
      if (bytes.length > MAX_BYTES) {
        return json({ error: "File exceeds 20 MB" }, 413);
      }
      if (!matchesFileSignature(bytes, contentType, ext)) {
        return json({ error: "File content does not match its type" }, 415);
      }

      const { data: payment, error: paymentError } = await admin
        .from("payments")
        .select("id,employee_id,company_id,deleted_at")
        .eq("id", paymentId)
        .maybeSingle();
      if (paymentError) throw paymentError;
      if (!payment) return json({ error: "Payment not found" }, 404);
      if (payment.deleted_at) return json({ error: "Payment is deleted" }, 409);

      const storageName = safeName(originalName).replace(/\s+/g, "_");
      const filePath =
        `${payment.employee_id}/${payment.id}/${Date.now()}_assistant_${
          crypto.randomUUID().slice(0, 8)
        }_${storageName}`;
      const { error: uploadError } = await admin.storage.from(BUCKET).upload(
        filePath,
        bytes,
        {
          contentType,
          cacheControl: "3600",
          upsert: false,
        },
      );
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
        .select(
          "id,payment_id,employee_id,company_id,file_name,file_path,content_type,created_at,upload_source",
        )
        .single();
      if (insertError) {
        await admin.storage.from(BUCKET).remove([filePath]);
        throw insertError;
      }
      return json({ ok: true, receipt }, 201);
    }

    if (action === "signed_download") {
      const receiptId = String(body.receipt_id ?? "").trim();
      if (!isUuid(receiptId)) {
        return json({ error: "receipt_id must be a UUID" }, 400);
      }
      const { data: receipt, error: receiptError } = await admin
        .from("payment_receipts")
        .select(
          "id,payment_id,employee_id,company_id,file_name,file_path,content_type,created_at,upload_source",
        )
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
    return json({ error: "Internal server error" }, 500);
  }
});
