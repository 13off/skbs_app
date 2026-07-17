import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const bucket = "recruitment-documents";

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

function botToken(): string {
  return Deno.env.get("TELEGRAM_RECRUITMENT_BOT_TOKEN")
    ?? Deno.env.get("TELEGRAM_BOT_TOKEN")
    ?? "";
}

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

function extension(filePath: string, mimeType: string): string {
  const fromPath = filePath.split(".").at(-1)?.toLowerCase() ?? "";
  if (["jpg", "jpeg", "png", "webp", "pdf"].includes(fromPath)) {
    return fromPath === "jpeg" ? "jpg" : fromPath;
  }
  switch (mimeType) {
    case "image/png":
      return "png";
    case "image/webp":
      return "webp";
    case "application/pdf":
      return "pdf";
    default:
      return "jpg";
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === "GET") {
    return json({
      name: "recruitment-ingest-telegram-file",
      token_configured: botToken().length > 0,
    });
  }
  if (request.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  try {
    const input = await request.json() as JsonMap;
    const kind = String(input.kind ?? "document");
    const id = String(input.id ?? "").trim();
    if (!id || !["document", "message"].includes(kind)) {
      return json({ error: "invalid payload" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const secret = serviceKey();
    const token = botToken();
    if (!supabaseUrl || !secret) {
      return json({ error: "service not configured" }, 500);
    }
    if (!token) {
      return json({ error: "telegram token not configured" }, 503);
    }

    const admin = createClient(supabaseUrl, secret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const table = kind === "document"
      ? "recruitment_documents"
      : "recruitment_messages";
    const select =
      "id,company_id,application_id,telegram_file_id,storage_bucket,storage_path,original_name,mime_type,size_bytes"
      + (kind === "document" ? ",document_type" : "");
    const { data, error } = await admin
      .from(table)
      .select(select)
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return json({ error: "row not found" }, 404);

    const existingPath = String(data.storage_path ?? "");
    if (
      String(data.storage_bucket ?? "") === bucket
      && existingPath
      && !existingPath.startsWith("telegram://")
    ) {
      return json({ ok: true, skipped: true, path: existingPath });
    }

    const fileId = String(data.telegram_file_id ?? "");
    if (!fileId) return json({ error: "telegram file id missing" }, 409);

    const getFileResponse = await fetch(
      `https://api.telegram.org/bot${token}/getFile?file_id=${encodeURIComponent(fileId)}`,
    );
    const getFileData = await getFileResponse.json() as JsonMap;
    if (!getFileResponse.ok || getFileData.ok !== true) {
      return json({
        error: String(getFileData.description ?? "Telegram getFile failed"),
      }, 502);
    }
    const result = (getFileData.result ?? {}) as JsonMap;
    const telegramPath = String(result.file_path ?? "");
    if (!telegramPath) {
      return json({ error: "Telegram file path missing" }, 502);
    }

    const downloadResponse = await fetch(
      `https://api.telegram.org/file/bot${token}/${telegramPath}`,
    );
    if (!downloadResponse.ok) {
      return json({ error: "Telegram file download failed" }, 502);
    }
    const bytes = new Uint8Array(await downloadResponse.arrayBuffer());
    if (!bytes.length) {
      return json({ error: "Telegram returned empty file" }, 502);
    }
    if (bytes.length > 20 * 1024 * 1024) {
      return json({ error: "File is too large" }, 413);
    }

    const mimeType = String(
      data.mime_type
        ?? downloadResponse.headers.get("content-type")
        ?? "application/octet-stream",
    );
    const ext = extension(telegramPath, mimeType);
    const category = kind === "document"
      ? String(data.document_type ?? "other")
      : "messages";
    const storagePath =
      `${String(data.company_id)}/${String(data.application_id)}/${category}/${String(data.id)}.${ext}`;
    const { error: uploadError } = await admin.storage
      .from(bucket)
      .upload(storagePath, bytes, {
        contentType: mimeType,
        upsert: true,
        cacheControl: "3600",
      });
    if (uploadError) throw uploadError;

    const updatePayload: JsonMap = {
      storage_bucket: bucket,
      storage_path: storagePath,
      original_name: String(data.original_name ?? "")
        || telegramPath.split("/").at(-1)
        || `file.${ext}`,
      mime_type: mimeType,
      size_bytes: bytes.length,
    };
    if (kind === "document") updatePayload.is_test_copy = false;

    const { error: updateError } = await admin
      .from(table)
      .update(updatePayload)
      .eq("id", id);
    if (updateError) throw updateError;
    return json({ ok: true, path: storagePath, size_bytes: bytes.length });
  } catch (error) {
    console.error("recruitment telegram file ingest failed", error);
    return json({
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});
