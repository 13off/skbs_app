import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const COMPANY_ID = "e39c8fd5-e7f3-4beb-a269-76e893975a98";
const SOURCE = "max";
const BUCKET = "recruitment-documents";
const MAX_BYTES = 20 * 1024 * 1024;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ALLOWED_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
]);

type JsonMap = Record<string, unknown>;

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

const admin = createClient(SUPABASE_URL, serviceKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});

function clean(value: unknown): string {
  return String(value ?? "").trim();
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json; charset=utf-8",
    },
  });
}

function relation(value: unknown): JsonMap {
  if (Array.isArray(value)) return (value[0] ?? {}) as JsonMap;
  if (value && typeof value === "object") return value as JsonMap;
  return {};
}

function safeName(value: string, mimeType: string): string {
  const fallback = mimeType === "application/pdf"
    ? "document.pdf"
    : mimeType === "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    ? "document.docx"
    : mimeType === "image/png"
    ? "photo.png"
    : mimeType === "image/webp"
    ? "photo.webp"
    : "photo.jpg";
  const source = clean(value) || fallback;
  const normalized = source
    .normalize("NFKC")
    .replace(/[\\/\u0000-\u001f\u007f]+/g, "_")
    .replace(/[^\p{L}\p{N}._()\- ]/gu, "_")
    .replace(/\s+/g, " ")
    .trim();
  return (normalized || fallback).slice(0, 160);
}

function pathSegment(value: string): string {
  return clean(value).replace(/[^a-zA-Z0-9._-]+/g, "_").slice(0, 180) || crypto.randomUUID();
}

function startsWith(bytes: Uint8Array, signature: number[]): boolean {
  return signature.every((value, index) => bytes[index] === value);
}

async function hasValidSignature(file: File, mimeType: string): Promise<boolean> {
  const bytes = new Uint8Array(await file.slice(0, 16).arrayBuffer());
  if (mimeType === "application/pdf") {
    return startsWith(bytes, [0x25, 0x50, 0x44, 0x46, 0x2d]);
  }
  if (mimeType === "image/jpeg") {
    return startsWith(bytes, [0xff, 0xd8, 0xff]);
  }
  if (mimeType === "image/png") {
    return startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  }
  if (mimeType === "image/webp") {
    return startsWith(bytes, [0x52, 0x49, 0x46, 0x46])
      && bytes[8] === 0x57
      && bytes[9] === 0x45
      && bytes[10] === 0x42
      && bytes[11] === 0x50;
  }
  if (mimeType === "application/vnd.openxmlformats-officedocument.wordprocessingml.document") {
    return startsWith(bytes, [0x50, 0x4b, 0x03, 0x04]);
  }
  return false;
}

async function expectedSecret(): Promise<string> {
  const { data, error } = await admin.rpc("get_recruitment_secret", {
    p_name: "max_recruitment_bridge_secret",
  });
  if (error) throw error;
  return clean(data);
}

async function authorized(request: Request): Promise<boolean> {
  const expected = await expectedSecret();
  const received = clean(request.headers.get("x-appstroy-max-secret"));
  return expected.length >= 24 && received === expected;
}

async function resolveApplication(fields: Record<string, string>): Promise<JsonMap | null> {
  let query = admin.from("recruitment_applications")
    .select("id,company_id,full_name,object_id,external_user_id,external_chat_id,source,archived_at,objects(name)")
    .eq("company_id", COMPANY_ID)
    .eq("source", SOURCE);

  if (fields.applicationId) {
    query = query.eq("id", fields.applicationId);
  } else if (fields.externalApplicationId) {
    query = query.eq("external_application_id", fields.externalApplicationId);
  } else if (fields.maxChatId) {
    query = query.eq("external_chat_id", fields.maxChatId).order("created_at", { ascending: false }).limit(1);
  } else if (fields.maxUserId) {
    query = query.eq("external_user_id", fields.maxUserId).order("created_at", { ascending: false }).limit(1);
  } else {
    return null;
  }

  const { data, error } = await query.maybeSingle();
  if (error) throw error;
  return data as JsonMap | null;
}

async function notifyRoles(application: JsonMap, fileName: string): Promise<void> {
  const objectRow = relation(application.objects);
  const body = `${clean(application.full_name) || "Кандидат"} · ${fileName}`;
  const rows = ["admin", "hr"].map((role) => ({
    company_id: COMPANY_ID,
    title: "Кандидат прислал файл в MAX",
    body,
    actor_name: clean(application.full_name) || "Кандидат",
    actor_email: "",
    object_name: clean(objectRow.name),
    entity_type: "recruitment_application",
    entity_id: clean(application.id),
    target_role: role,
    requires_action: true,
    priority: "high",
    source_role: "system",
    push_requested: true,
  }));
  const { error } = await admin.from("app_notifications").insert(rows);
  if (error) console.error("MAX file notification failed", error);
}

async function alreadySaved(externalMessageId: string): Promise<JsonMap | null> {
  const { data, error } = await admin.from("recruitment_messages")
    .select("id,storage_bucket,storage_path")
    .eq("transport", SOURCE)
    .eq("external_message_id", externalMessageId)
    .maybeSingle();
  if (error) throw error;
  return data as JsonMap | null;
}

Deno.serve(async (request: Request) => {
  let uploadedPath = "";
  try {
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    if (!(await authorized(request))) return json({ error: "forbidden" }, 403);

    const contentType = request.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().includes("multipart/form-data")) {
      return json({ error: "multipart_required" }, 400);
    }

    const form = await request.formData();
    const fileValue = form.get("file");
    if (!(fileValue instanceof File)) return json({ error: "file_required" }, 400);

    const fields: Record<string, string> = {
      applicationId: clean(form.get("applicationId")),
      externalApplicationId: clean(form.get("externalApplicationId")),
      maxUserId: clean(form.get("maxUserId")),
      maxChatId: clean(form.get("maxChatId")),
      maxMessageId: clean(form.get("maxMessageId")),
      attachmentId: clean(form.get("attachmentId")),
      text: clean(form.get("text")),
      documentType: clean(form.get("documentType")) || "other",
      originalName: clean(form.get("originalName")),
      mimeType: clean(form.get("mimeType")),
    };

    if (!fields.maxMessageId || !fields.attachmentId) {
      return json({ error: "missing_external_identity" }, 400);
    }

    const externalMessageId = `${fields.maxMessageId}:${fields.attachmentId}`;
    const existing = await alreadySaved(externalMessageId);
    if (existing) {
      return json({
        ok: true,
        duplicate: true,
        messageId: clean(existing.id),
        storageBucket: clean(existing.storage_bucket),
        storagePath: clean(existing.storage_path),
      });
    }

    const application = await resolveApplication(fields);
    if (!application || application.archived_at) return json({ error: "application_not_found" }, 404);

    const mimeType = (fields.mimeType || fileValue.type || "application/octet-stream").toLowerCase();
    if (!ALLOWED_MIME_TYPES.has(mimeType)) {
      return json({ error: "unsupported_file_type", mimeType }, 415);
    }
    if (fileValue.size <= 0 || fileValue.size > MAX_BYTES) {
      return json({ error: "file_too_large", maxBytes: MAX_BYTES }, 413);
    }
    if (!(await hasValidSignature(fileValue, mimeType))) {
      return json({ error: "file_signature_mismatch" }, 415);
    }

    const originalName = safeName(fields.originalName || fileValue.name, mimeType);
    const applicationId = clean(application.id);
    const suffix = `${Date.now()}-${pathSegment(fields.attachmentId)}-${pathSegment(originalName)}`;
    uploadedPath = `${COMPANY_ID}/${applicationId}/max/${suffix}`;

    const { error: uploadError } = await admin.storage.from(BUCKET).upload(uploadedPath, fileValue, {
      contentType: mimeType,
      cacheControl: "3600",
      upsert: false,
    });
    if (uploadError) throw uploadError;

    const { data: message, error: messageError } = await admin.from("recruitment_messages").insert({
      company_id: COMPANY_ID,
      application_id: applicationId,
      direction: "inbound",
      message_text: fields.text.slice(0, 3500),
      storage_bucket: BUCKET,
      storage_path: uploadedPath,
      original_name: originalName,
      mime_type: mimeType,
      size_bytes: fileValue.size,
      transport: SOURCE,
      external_message_id: externalMessageId,
      delivery_status: "received",
    }).select("id").single();

    if (messageError) {
      if (String(messageError.code) === "23505") {
        await admin.storage.from(BUCKET).remove([uploadedPath]);
        uploadedPath = "";
        const duplicate = await alreadySaved(externalMessageId);
        return json({ ok: true, duplicate: true, messageId: clean(duplicate?.id) });
      }
      throw messageError;
    }

    const externalFileId = fields.attachmentId;
    const { error: documentError } = await admin.from("recruitment_documents").insert({
      company_id: COMPANY_ID,
      application_id: applicationId,
      document_type: ["passport_main", "registration", "snils", "inn", "policy", "other"].includes(fields.documentType)
        ? fields.documentType
        : "other",
      telegram_file_id: "",
      telegram_file_unique_id: "",
      transport: SOURCE,
      external_file_id: externalFileId,
      external_file_unique_id: externalMessageId,
      storage_bucket: BUCKET,
      storage_path: uploadedPath,
      original_name: originalName,
      mime_type: mimeType,
      size_bytes: fileValue.size,
      is_test_copy: false,
    });
    if (documentError && String(documentError.code) !== "23505") {
      console.error("MAX recruitment document row failed", documentError);
    }

    await notifyRoles(application, originalName);
    return json({
      ok: true,
      messageId: clean(message.id),
      storageBucket: BUCKET,
      storagePath: uploadedPath,
      originalName,
      mimeType,
      sizeBytes: fileValue.size,
    }, 201);
  } catch (error) {
    console.error("MAX recruitment file bridge failed", error);
    if (uploadedPath) {
      await admin.storage.from(BUCKET).remove([uploadedPath]).catch(() => null);
    }
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
