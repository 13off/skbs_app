import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";
import JSZip from "npm:jszip@3.10.1";

const COMPANY_ID = "e39c8fd5-e7f3-4beb-a269-76e893975a98";
const BUCKET = "recruitment-documents";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const MAX_ARCHIVE_BYTES = 5 * 1024 * 1024;
const MAX_REQUEST_BYTES = MAX_ARCHIVE_BYTES + 512 * 1024;
const MAX_ENTRY_BYTES = 20 * 1024 * 1024;
const MAX_UNCOMPRESSED_BYTES = 160 * 1024 * 1024;
const MAX_MANIFEST_BYTES = 512 * 1024;

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

const admin = createClient(SUPABASE_URL, serviceKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});

type ManifestItem = {
  applicationId?: string;
  fullName?: string;
  documentType?: string;
  fileName?: string;
  mimeType?: string;
  externalFileId?: string;
  externalFileUniqueId?: string;
  sha256?: string;
};
type JsonObject = Record<string, unknown>;
type ZipEntryWithSize = { _data?: { uncompressedSize?: number } };

class ImportInputError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ImportInputError";
  }
}

const allowedTypes = new Set([
  "passport_main",
  "registration",
  "snils",
  "inn",
  "policy",
  "other",
]);
const allowedMime = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
]);
const clean = (value: unknown) => String(value ?? "").trim();
const html = (body: string, status = 200) =>
  new Response(body, {
    status,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "content-security-policy":
        "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    },
  });

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) =>
    ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    })[character] ?? character);
}

function ownedArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}

async function readLimitedBody(
  request: Request,
  maxBytes: number,
): Promise<Uint8Array> {
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    length += value.byteLength;
    if (length > maxBytes) {
      await reader.cancel();
      throw new RangeError("Request body is too large");
    }
    chunks.push(value);
  }
  const result = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return result;
}

async function hashHex(value: string | Uint8Array): Promise<string> {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value).buffer
    : ownedArrayBuffer(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function validToken(token: string): Promise<boolean> {
  if (!token) return false;
  const tokenHash = await hashHex(token);
  const staleBefore = new Date(Date.now() - 30 * 60_000).toISOString();
  const { data, error } = await admin
    .from("recruitment_import_tokens")
    .select("token_hash")
    .eq("token_hash", tokenHash)
    .eq("purpose", "candidate_documents")
    .is("used_at", null)
    .gt("expires_at", new Date().toISOString())
    .or(`processing_at.is.null,processing_at.lt.${staleBefore}`)
    .maybeSingle();
  if (error) throw error;
  return Boolean(data);
}

async function claimToken(
  token: string,
): Promise<{ hash: string; nonce: string } | null> {
  const hash = await hashHex(token);
  const { data, error } = await admin.rpc("claim_recruitment_import_token", {
    p_token_hash: hash,
  });
  if (error) throw error;
  const nonce = clean(data);
  return nonce ? { hash, nonce } : null;
}

async function releaseToken(hash: string, nonce: string): Promise<void> {
  const { data, error } = await admin.rpc("release_recruitment_import_token", {
    p_token_hash: hash,
    p_processing_nonce: nonce,
  });
  if (error) throw error;
  if (data !== true) throw new Error("Не удалось освободить токен импорта");
}

async function completeToken(hash: string, nonce: string): Promise<boolean> {
  const { data, error } = await admin.rpc("complete_recruitment_import_token", {
    p_token_hash: hash,
    p_processing_nonce: nonce,
  });
  if (error) throw error;
  return data === true;
}

function safeName(value: string, mime: string): string {
  const fallback = mime === "application/pdf"
    ? "document.pdf"
    : mime === "image/webp"
    ? "photo.webp"
    : mime === "image/png"
    ? "photo.png"
    : "photo.jpg";
  return (clean(value)
    .normalize("NFKC")
    // deno-lint-ignore no-control-regex -- Strip control bytes from filenames.
    .replace(/[\\/\u0000-\u001f\u007f]+/g, "_")
    .replace(/[^\p{L}\p{N}._()\- ]/gu, "_")
    .replace(/\s+/g, " ")
    .replace(/^\.+|\.+$/g, "")
    .trim() || fallback).slice(0, 180);
}

function startsWith(bytes: Uint8Array, signature: number[]): boolean {
  return signature.every((value, index) => bytes[index] === value);
}

function validSignature(bytes: Uint8Array, mime: string): boolean {
  if (mime === "application/pdf") {
    return startsWith(bytes, [0x25, 0x50, 0x44, 0x46, 0x2d]);
  }
  if (mime === "image/jpeg") return startsWith(bytes, [0xff, 0xd8, 0xff]);
  if (mime === "image/png") {
    return startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  }
  if (mime === "image/webp") {
    return startsWith(bytes, [0x52, 0x49, 0x46, 0x46]) &&
      bytes[8] === 0x57 && bytes[9] === 0x45 &&
      bytes[10] === 0x42 && bytes[11] === 0x50;
  }
  return false;
}

function uncompressedSize(entry: unknown): number {
  return Number((entry as ZipEntryWithSize)._data?.uncompressedSize ?? 0);
}

function validateArchiveShape(zip: JSZip): void {
  let total = 0;
  for (const entry of Object.values(zip.files)) {
    if (entry.dir) continue;
    const size = uncompressedSize(entry);
    if (!Number.isFinite(size) || size < 0 || size > MAX_ENTRY_BYTES) {
      throw new ImportInputError("Один из файлов архива слишком большой");
    }
    total += size;
    if (total > MAX_UNCOMPRESSED_BYTES) {
      throw new ImportInputError("Распакованный архив слишком большой");
    }
  }
  const manifest = zip.file("manifest.json");
  if (manifest && uncompressedSize(manifest) > MAX_MANIFEST_BYTES) {
    throw new ImportInputError("manifest.json слишком большой");
  }
}

function validateManifest(manifest: ManifestItem[], zip: JSZip): void {
  if (manifest.length !== 32) {
    throw new ImportInputError("Ожидалось 32 документа");
  }
  const documentKeys = new Set<string>();
  const fileNames = new Set<string>();
  for (const item of manifest) {
    const applicationId = clean(item.applicationId);
    const documentType = clean(item.documentType) || "other";
    const fileName = clean(item.fileName);
    const mimeType = clean(item.mimeType).toLowerCase();
    const sha = clean(item.sha256).toLowerCase();
    if (
      !applicationId || !fileName || !allowedTypes.has(documentType) ||
      !allowedMime.has(mimeType) || !/^[a-f0-9]{64}$/.test(sha)
    ) {
      throw new ImportInputError("Некорректная запись манифеста");
    }
    if (!zip.file(fileName)) {
      throw new ImportInputError("Файл из манифеста отсутствует");
    }
    const documentKey = `${applicationId}:${documentType}`;
    if (documentKeys.has(documentKey) || fileNames.has(fileName)) {
      throw new ImportInputError("В манифесте есть дубли");
    }
    documentKeys.add(documentKey);
    fileNames.add(fileName);
  }
}

async function markImported(applicationId: string): Promise<void> {
  const { data, error } = await admin
    .from("recruitment_applications")
    .select("custom_values")
    .eq("id", applicationId)
    .eq("company_id", COMPANY_ID)
    .single();
  if (error) throw error;
  const current = data?.custom_values && typeof data.custom_values === "object"
    ? data.custom_values as JsonObject
    : {};
  const { error: updateError } = await admin
    .from("recruitment_applications")
    .update({
      custom_values: {
        ...current,
        physical_storage_status: "imported",
        physical_documents_imported_at: new Date().toISOString(),
      },
    })
    .eq("id", applicationId)
    .eq("company_id", COMPANY_ID);
  if (updateError) throw updateError;
}

function page(token: string, message = ""): string {
  const safeToken = escapeHtml(token);
  const safeMessage = escapeHtml(message);
  const messageBlock = safeMessage
    ? `<div class="msg">${safeMessage}</div>`
    : "";
  return `<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Импорт документов AppСтрой</title><style>body{font-family:Arial,sans-serif;background:#f5f5f5;margin:0;padding:24px}.card{max-width:560px;margin:8vh auto;background:#fff;padding:28px;border-radius:16px;box-shadow:0 8px 30px #0001}h1{font-size:24px;margin-top:0}p{color:#555;line-height:1.5}input{display:block;width:100%;box-sizing:border-box;padding:14px;border:1px solid #ccc;border-radius:10px;margin:18px 0}button{width:100%;padding:14px;border:0;border-radius:10px;background:#111;color:#fff;font-size:16px;font-weight:700;cursor:pointer}.msg{padding:12px;background:#eef7ee;border-radius:8px;margin-bottom:14px}</style></head><body><div class="card"><h1>Импорт документов в HR</h1>${messageBlock}<p>Выберите подготовленный ZIP-архив. Он будет проверен и загружен в закрытое хранилище AppСтрой.</p><form method="post" enctype="multipart/form-data"><input type="hidden" name="token" value="${safeToken}"><input type="file" name="archive" accept=".zip,application/zip" required><button type="submit">Загрузить документы</button></form></div></body></html>`;
}

Deno.serve(async (request: Request) => {
  let claim: { hash: string; nonce: string } | null = null;
  let token = "";
  try {
    const url = new URL(request.url);
    if (request.method === "GET") {
      token = clean(url.searchParams.get("token"));
      if (!await validToken(token)) {
        return html("Ссылка недействительна, занята или истекла.", 403);
      }
      return html(page(token));
    }
    if (request.method !== "POST") return html("Метод не поддерживается", 405);

    const declaredLength = Number(request.headers.get("content-length") ?? 0);
    if (Number.isFinite(declaredLength) && declaredLength > MAX_REQUEST_BYTES) {
      return html("Запрос слишком большой.", 413);
    }
    const contentType = clean(request.headers.get("content-type"));
    if (!contentType.toLowerCase().startsWith("multipart/form-data;")) {
      return html("Ожидается ZIP-файл в форме.", 415);
    }
    let requestBytes: Uint8Array;
    try {
      requestBytes = await readLimitedBody(request, MAX_REQUEST_BYTES);
    } catch (error) {
      if (error instanceof RangeError) {
        return html("Запрос слишком большой.", 413);
      }
      throw error;
    }
    let form: FormData;
    try {
      form = await new Response(ownedArrayBuffer(requestBytes), {
        headers: { "content-type": contentType },
      }).formData();
    } catch (_) {
      throw new ImportInputError("Не удалось прочитать форму загрузки");
    }
    token = clean(form.get("token"));
    const file = form.get("archive");
    if (!(file instanceof File)) {
      return html(page(token, "Файл не выбран."), 400);
    }
    if (file.size <= 0 || file.size > MAX_ARCHIVE_BYTES) {
      return html(page(token, "Архив слишком большой."), 413);
    }

    claim = await claimToken(token);
    if (!claim) {
      return html(
        "Ссылка недействительна, уже используется или погашена.",
        403,
      );
    }

    let zip: JSZip;
    try {
      zip = await JSZip.loadAsync(new Uint8Array(await file.arrayBuffer()));
    } catch (_) {
      throw new ImportInputError("Не удалось прочитать ZIP-архив");
    }
    validateArchiveShape(zip);
    const manifestEntry = zip.file("manifest.json");
    if (!manifestEntry) {
      throw new ImportInputError("В архиве отсутствует manifest.json");
    }
    let manifest: ManifestItem[];
    try {
      manifest = JSON.parse(
        await manifestEntry.async("text"),
      ) as ManifestItem[];
    } catch (_) {
      throw new ImportInputError("Некорректный manifest.json");
    }
    if (!Array.isArray(manifest)) {
      throw new ImportInputError("Некорректный manifest.json");
    }
    validateManifest(manifest, zip);

    let imported = 0;
    let skipped = 0;
    const failures: string[] = [];
    for (const item of manifest) {
      let uploadedPath = "";
      const applicationId = clean(item.applicationId);
      const fullName = clean(item.fullName) || applicationId;
      try {
        const documentType = clean(item.documentType) || "other";
        const fileName = clean(item.fileName);
        const mimeType = clean(item.mimeType).toLowerCase();
        const externalFileId = clean(item.externalFileId);
        const externalUnique = clean(item.externalFileUniqueId) ||
          externalFileId;

        const { data: application, error: applicationError } = await admin
          .from("recruitment_applications")
          .select("id,archived_at")
          .eq("id", applicationId)
          .eq("company_id", COMPANY_ID)
          .maybeSingle();
        if (applicationError) throw applicationError;
        if (!application || application.archived_at) {
          throw new ImportInputError("Карточка кандидата не найдена");
        }
        const { data: existing, error: existingError } = await admin
          .from("recruitment_documents")
          .select("id")
          .eq("company_id", COMPANY_ID)
          .eq("application_id", applicationId)
          .eq("document_type", documentType)
          .maybeSingle();
        if (existingError) throw existingError;
        if (existing) {
          await markImported(applicationId);
          skipped++;
          continue;
        }

        const entry = zip.file(fileName)!;
        const bytes = await entry.async("uint8array");
        if (
          bytes.byteLength > MAX_ENTRY_BYTES || !validSignature(bytes, mimeType)
        ) {
          throw new ImportInputError("Неверный формат или размер файла");
        }
        if (await hashHex(bytes) !== clean(item.sha256).toLowerCase()) {
          throw new ImportInputError("Контрольная сумма не совпала");
        }
        const originalName = safeName(
          fileName.replace(/^[^_]+__[^_]+__/, ""),
          mimeType,
        );
        uploadedPath =
          `${COMPANY_ID}/${applicationId}/google_drive/${Date.now()}-${crypto.randomUUID()}-${originalName}`;
        const { error: uploadError } = await admin.storage
          .from(BUCKET)
          .upload(
            uploadedPath,
            new Blob([ownedArrayBuffer(bytes)], { type: mimeType }),
            {
              contentType: mimeType,
              cacheControl: "3600",
              upsert: false,
            },
          );
        if (uploadError) throw uploadError;

        const { error: insertError } = await admin
          .from("recruitment_documents")
          .insert({
            company_id: COMPANY_ID,
            application_id: applicationId,
            document_type: documentType,
            telegram_file_id: "",
            telegram_file_unique_id: "",
            storage_bucket: BUCKET,
            storage_path: uploadedPath,
            original_name: originalName,
            mime_type: mimeType,
            size_bytes: bytes.byteLength,
            is_test_copy: false,
            transport: "google_drive",
            external_file_id: externalFileId,
            external_file_unique_id: externalUnique,
          });
        if (insertError) {
          await admin.storage.from(BUCKET).remove([uploadedPath]);
          uploadedPath = "";
          throw insertError;
        }
        await markImported(applicationId);
        imported++;
      } catch (error) {
        if (uploadedPath) {
          await admin.storage.from(BUCKET).remove([uploadedPath]).catch(() =>
            null
          );
        }
        console.error("Recruitment document import item failed", {
          applicationId,
          error,
        });
        const message = error instanceof ImportInputError
          ? error.message
          : "Не удалось сохранить документ";
        failures.push(`${fullName}: ${message}`);
      }
    }

    if (failures.length) {
      await releaseToken(claim.hash, claim.nonce);
      claim = null;
      return html(
        page(
          token,
          `Загружено: ${imported}, пропущено: ${skipped}. Ошибки: ${
            failures.join("; ")
          }`,
        ),
        207,
      );
    }
    if (!await completeToken(claim.hash, claim.nonce)) {
      throw new Error("Не удалось завершить одноразовый импорт");
    }
    claim = null;
    return html(
      `<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><body style="font-family:Arial;padding:40px"><h1>Готово</h1><p>Документы загружены: ${imported}. Уже существовали: ${skipped}.</p><p>Ссылку можно закрыть.</p></body></html>`,
    );
  } catch (error) {
    if (claim) await releaseToken(claim.hash, claim.nonce).catch(() => null);
    console.error("Recruitment archive import failed", error);
    const message = error instanceof ImportInputError
      ? error.message
      : "Внутренняя ошибка импорта. Попробуйте ещё раз";
    return html(`Ошибка импорта: ${escapeHtml(message)}`, 500);
  }
});
