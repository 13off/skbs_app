import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.110.5";

const bucket = "recruitment-documents";
const maxBytes = 20 * 1024 * 1024;
const maxRequestBytes = 4 * 1024;
const secretConfigName = "recruitment_ingest";
let cachedSecretSha256 = "";
let cachedBotToken = "";

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

function botTokenFromEnvironment(): string {
  return Deno.env.get("TELEGRAM_RECRUITMENT_BOT_TOKEN") ??
    Deno.env.get("TELEGRAM_BOT_TOKEN") ??
    "";
}

type JsonMap = Record<string, unknown>;

type TelegramFileRow = {
  id: string;
  company_id: string;
  application_id: string;
  telegram_file_id: string | null;
  storage_bucket: string | null;
  storage_path: string | null;
  original_name: string | null;
  mime_type: string | null;
  size_bytes: number | null;
  document_type?: string | null;
};

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
      return "";
  }
}

function mimeForExtension(ext: string): string {
  switch (ext) {
    case "pdf":
      return "application/pdf";
    case "png":
      return "image/png";
    case "webp":
      return "image/webp";
    default:
      return "image/jpeg";
  }
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function safeOriginalName(value: string, ext: string): string {
  const normalized = value.normalize("NFKC")
    // deno-lint-ignore no-control-regex -- Strip control bytes from filenames.
    .replace(/[\u0000-\u001f\u007f]+/g, "_")
    .replace(/[\\/]+/g, "_")
    .replace(/[^\p{L}\p{N}._()\- ]/gu, "_")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 180);
  return normalized || `file.${ext}`;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function isSha256(value: string): boolean {
  return /^[0-9a-f]{64}$/.test(value);
}

function sameText(first: string, second: string): boolean {
  if (first.length !== second.length) return false;
  let difference = 0;
  for (let index = 0; index < first.length; index += 1) {
    difference |= first.charCodeAt(index) ^ second.charCodeAt(index);
  }
  return difference === 0;
}

async function configuredSecretSha256(admin: SupabaseClient): Promise<string> {
  const fromEnvironment = Deno.env.get("RECRUITMENT_INGEST_SECRET_SHA256")
    ?.trim().toLowerCase() ?? "";
  if (isSha256(fromEnvironment)) return fromEnvironment;
  if (isSha256(cachedSecretSha256)) return cachedSecretSha256;

  const { data, error } = await admin
    .from("edge_auth_secret_hashes")
    .select("secret_sha256")
    .eq("name", secretConfigName)
    .maybeSingle();
  if (error) throw error;

  const fromDatabase = String(data?.secret_sha256 ?? "").trim().toLowerCase();
  if (isSha256(fromDatabase)) cachedSecretSha256 = fromDatabase;
  return cachedSecretSha256;
}

async function isAuthorized(
  request: Request,
  admin: SupabaseClient,
): Promise<boolean> {
  const expected = await configuredSecretSha256(admin);
  const supplied = request.headers.get("x-recruitment-ingest-secret") ?? "";
  if (!expected || !supplied) return false;
  return sameText(await sha256(supplied), expected);
}

async function configuredBotToken(admin: SupabaseClient): Promise<string> {
  const fromEnvironment = botTokenFromEnvironment().trim();
  if (fromEnvironment) return fromEnvironment;
  if (cachedBotToken) return cachedBotToken;

  const { data, error } = await admin.rpc("get_recruitment_secret", {
    p_name: "telegram_recruitment_bot_token",
  });
  if (error) throw error;
  const fromVault = String(data ?? "").trim();
  if (fromVault) cachedBotToken = fromVault;
  return cachedBotToken;
}

async function readLimited(response: Response): Promise<Uint8Array> {
  const declaredLength = Number(response.headers.get("content-length") ?? 0);
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    throw new RangeError("File is too large");
  }
  if (!response.body) return new Uint8Array();

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    length += value.length;
    if (length > maxBytes) {
      await reader.cancel();
      throw new RangeError("File is too large");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return bytes;
}

function matchesFileSignature(bytes: Uint8Array, ext: string): boolean {
  if (ext === "pdf") {
    return bytes.length >= 5 &&
      String.fromCharCode(...bytes.slice(0, 5)) === "%PDF-";
  }
  if (ext === "jpg") {
    return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
      bytes[2] === 0xff;
  }
  if (ext === "png") {
    return bytes.length >= 8 &&
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
        .every((value, index) => bytes[index] === value);
  }
  if (ext === "webp") {
    return bytes.length >= 12 &&
      String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
  }
  return false;
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const secret = serviceKey();
    if (!supabaseUrl || !secret) {
      return json({ error: "service not configured" }, 500);
    }
    const admin = createClient(supabaseUrl, secret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (!await isAuthorized(request, admin)) {
      return json({ error: "unauthorized" }, 401);
    }

    const declaredLength = Number(request.headers.get("content-length") ?? 0);
    if (Number.isFinite(declaredLength) && declaredLength > maxRequestBytes) {
      return json({ error: "payload too large" }, 413);
    }
    const rawInput = await request.text();
    if (!rawInput || rawInput.length > maxRequestBytes) {
      return json({ error: "invalid payload" }, 400);
    }
    let input: JsonMap;
    try {
      input = JSON.parse(rawInput) as JsonMap;
    } catch (_) {
      return json({ error: "invalid payload" }, 400);
    }
    const kind = String(input.kind ?? "document");
    const id = String(input.id ?? "").trim();
    if (!isUuid(id) || !["document", "message"].includes(kind)) {
      return json({ error: "invalid payload" }, 400);
    }

    const token = await configuredBotToken(admin);
    if (!token) {
      return json({ error: "telegram token not configured" }, 503);
    }

    const table = kind === "document"
      ? "recruitment_documents"
      : "recruitment_messages";
    const select =
      "id,company_id,application_id,telegram_file_id,storage_bucket,storage_path,original_name,mime_type,size_bytes" +
      (kind === "document" ? ",document_type" : "");
    const { data, error } = await admin
      .from(table)
      .select(select)
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    if (!data) return json({ error: "row not found" }, 404);
    const row = data as unknown as TelegramFileRow;

    const existingPath = String(row.storage_path ?? "");
    if (
      String(row.storage_bucket ?? "") === bucket &&
      existingPath &&
      !existingPath.startsWith("telegram://")
    ) {
      return json({ ok: true, skipped: true, path: existingPath });
    }

    const fileId = String(row.telegram_file_id ?? "");
    if (!fileId) return json({ error: "telegram file id missing" }, 409);

    const getFileResponse = await fetch(
      `https://api.telegram.org/bot${token}/getFile?file_id=${
        encodeURIComponent(fileId)
      }`,
      { signal: AbortSignal.timeout(10_000) },
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
      { signal: AbortSignal.timeout(30_000) },
    );
    if (!downloadResponse.ok) {
      return json({ error: "Telegram file download failed" }, 502);
    }
    let bytes: Uint8Array;
    try {
      bytes = await readLimited(downloadResponse);
    } catch (error) {
      if (error instanceof RangeError) {
        return json({ error: "File is too large" }, 413);
      }
      throw error;
    }
    if (!bytes.length) {
      return json({ error: "Telegram returned empty file" }, 502);
    }
    const declaredMimeType = String(
      row.mime_type ??
        downloadResponse.headers.get("content-type") ??
        "application/octet-stream",
    );
    const ext = extension(telegramPath, declaredMimeType);
    if (!ext || !matchesFileSignature(bytes, ext)) {
      return json({ error: "Unsupported or invalid file" }, 415);
    }
    const mimeType = mimeForExtension(ext);
    const rawCategory = kind === "document"
      ? String(row.document_type ?? "other")
      : "messages";
    const category = /^[a-z0-9_-]{1,50}$/i.test(rawCategory)
      ? rawCategory
      : "other";
    const storagePath = `${String(row.company_id)}/${
      String(row.application_id)
    }/${category}/${String(row.id)}.${ext}`;
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
      original_name: safeOriginalName(
        String(row.original_name ?? "") ||
          telegramPath.split("/").at(-1) ||
          `file.${ext}`,
        ext,
      ),
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
    return json({ error: "internal_error" }, 500);
  }
});
