import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";
import JSZip from "npm:jszip@3.10.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const documentsBucket = "recruitment-documents";

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
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

function botToken(): string {
  return Deno.env.get("TELEGRAM_RECRUITMENT_BOT_TOKEN")
    ?? Deno.env.get("TELEGRAM_BOT_TOKEN")
    ?? "";
}

type JsonMap = Record<string, unknown>;

type ApplicationRow = {
  id: string;
  company_id: string;
  full_name: string;
  source: string;
  external_chat_id: string;
  status: string;
  archived_at: string | null;
};

type DocumentRow = {
  document_type: string;
  storage_bucket: string;
  storage_path: string;
  original_name: string;
  mime_type: string;
};

function safeFileName(value: string, fallback: string): string {
  const clean = value
    .trim()
    .replace(/[\\/:*?"<>|\u0000-\u001F]/g, "_")
    .replace(/\s+/g, " ")
    .replace(/^\.+|\.+$/g, "")
    .slice(0, 120);
  return clean || fallback;
}

function extensionFrom(row: DocumentRow): string {
  const fromName = row.original_name.split(".").at(-1)?.toLowerCase() ?? "";
  const fromPath = row.storage_path.split(".").at(-1)?.toLowerCase() ?? "";
  for (const value of [fromName, fromPath]) {
    if (["jpg", "jpeg", "png", "webp", "pdf"].includes(value)) {
      return value === "jpeg" ? "jpg" : value;
    }
  }
  switch (row.mime_type) {
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

function documentTitle(type: string): string {
  switch (type) {
    case "passport_main":
      return "Паспорт — разворот";
    case "registration":
      return "Паспорт — регистрация";
    case "snils":
      return "СНИЛС";
    case "inn":
      return "ИНН";
    case "policy":
      return "Медицинский полис";
    default:
      return "Документ";
  }
}

async function createDocumentsArchive(
  admin: ReturnType<typeof createClient>,
  application: ApplicationRow,
) {
  const { data, error } = await admin
    .from("recruitment_documents")
    .select(
      "document_type,storage_bucket,storage_path,original_name,mime_type",
    )
    .eq("company_id", application.company_id)
    .eq("application_id", application.id)
    .order("created_at");
  if (error) throw error;

  const documents = ((data ?? []) as DocumentRow[]).filter((row) =>
    row.storage_bucket.trim().length > 0
    && row.storage_path.trim().length > 0
    && !row.storage_path.startsWith("telegram://")
  );
  if (!documents.length) {
    throw new Error("У кандидата пока нет загруженных документов");
  }

  const zip = new JSZip();
  const usedNames = new Set<string>();
  for (let index = 0; index < documents.length; index += 1) {
    const row = documents[index];
    const { data: blob, error: downloadError } = await admin.storage
      .from(row.storage_bucket)
      .download(row.storage_path);
    if (downloadError) throw downloadError;

    const ext = extensionFrom(row);
    const preferred = row.original_name.trim().length > 0
      ? safeFileName(row.original_name, `document_${index + 1}.${ext}`)
      : `${documentTitle(row.document_type)}.${ext}`;
    let fileName = safeFileName(preferred, `document_${index + 1}.${ext}`);
    if (!fileName.toLowerCase().endsWith(`.${ext}`)) {
      fileName = `${fileName}.${ext}`;
    }
    if (usedNames.has(fileName.toLowerCase())) {
      const dot = fileName.lastIndexOf(".");
      const base = dot > 0 ? fileName.slice(0, dot) : fileName;
      const suffix = dot > 0 ? fileName.slice(dot) : "";
      fileName = `${base}_${index + 1}${suffix}`;
    }
    usedNames.add(fileName.toLowerCase());
    zip.file(fileName, new Uint8Array(await blob.arrayBuffer()));
  }

  const bytes = await zip.generateAsync({
    type: "uint8array",
    compression: "DEFLATE",
    compressionOptions: { level: 6 },
  });
  const archivePath =
    `${application.company_id}/${application.id}/exports/documents.zip`;
  const { error: uploadError } = await admin.storage
    .from(documentsBucket)
    .upload(archivePath, bytes, {
      contentType: "application/zip",
      upsert: true,
      cacheControl: "300",
    });
  if (uploadError) throw uploadError;

  const archiveName = safeFileName(
    `${application.full_name} — документы.zip`,
    "documents.zip",
  );
  const { data: signed, error: signedError } = await admin.storage
    .from(documentsBucket)
    .createSignedUrl(archivePath, 300, { download: archiveName });
  if (signedError) throw signedError;
  return { url: signed.signedUrl, count: documents.length };
}

async function removeStoredFiles(
  admin: ReturnType<typeof createClient>,
  application: ApplicationRow,
) {
  const [
    { data: documents, error: documentsError },
    { data: messages, error: messagesError },
  ] = await Promise.all([
    admin
      .from("recruitment_documents")
      .select("storage_bucket,storage_path")
      .eq("application_id", application.id),
    admin
      .from("recruitment_messages")
      .select("storage_bucket,storage_path")
      .eq("application_id", application.id),
  ]);
  if (documentsError) throw documentsError;
  if (messagesError) throw messagesError;

  const grouped = new Map<string, Set<string>>();
  for (const row of [...(documents ?? []), ...(messages ?? [])]) {
    const bucket = String(row.storage_bucket ?? "").trim();
    const path = String(row.storage_path ?? "").trim();
    if (!bucket || !path || path.startsWith("telegram://")) continue;
    const paths = grouped.get(bucket) ?? new Set<string>();
    paths.add(path);
    grouped.set(bucket, paths);
  }

  const archivePaths = grouped.get(documentsBucket) ?? new Set<string>();
  archivePaths.add(
    `${application.company_id}/${application.id}/exports/documents.zip`,
  );
  grouped.set(documentsBucket, archivePaths);

  for (const [bucket, paths] of grouped.entries()) {
    if (!paths.size) continue;
    const { error } = await admin.storage.from(bucket).remove([...paths]);
    if (error) throw error;
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return response({ error: "Метод не поддерживается" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authorization = request.headers.get("Authorization") ?? "";
    const secret = serviceKey();
    if (!supabaseUrl || !anonKey || !secret || !authorization) {
      return response({ error: "Сервис не настроен" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
      return response({ error: "Требуется повторный вход" }, 401);
    }

    const body = await request.json() as JsonMap;
    const action = String(body.action ?? "").trim();
    const applicationId = String(body.application_id ?? "").trim();
    if (!applicationId) {
      return response({ error: "Не указана заявка" }, 400);
    }

    const admin = createClient(supabaseUrl, secret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: applicationData, error: applicationError } = await admin
      .from("recruitment_applications")
      .select(
        "id,company_id,full_name,source,external_chat_id,status,archived_at",
      )
      .eq("id", applicationId)
      .maybeSingle();
    if (applicationError) throw applicationError;
    if (!applicationData) {
      return response({ error: "Заявка не найдена" }, 404);
    }
    const application = applicationData as ApplicationRow;

    const { data: membership, error: membershipError } = await admin
      .from("company_memberships")
      .select("role,is_active")
      .eq("company_id", application.company_id)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .in("role", ["owner", "admin", "hr"])
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) {
      return response({ error: "Нет доступа к заявке" }, 403);
    }

    if (action === "create_documents_archive") {
      return response({
        ok: true,
        ...(await createDocumentsArchive(admin, application)),
      });
    }

    if (action === "send_message") {
      const text = String(body.message ?? "").trim();
      if (!text || text.length > 3500) {
        return response({
          error: "Сообщение должно содержать от 1 до 3500 символов",
        }, 400);
      }
      if (application.source !== "telegram" || !application.external_chat_id) {
        return response({
          error: "Кандидат недоступен через Telegram-бота",
        }, 409);
      }
      const token = botToken();
      if (!token) {
        return response({ error: "Токен Telegram-бота не подключён" }, 503);
      }

      const telegramResponse = await fetch(
        `https://api.telegram.org/bot${token}/sendMessage`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            chat_id: application.external_chat_id,
            text,
            disable_web_page_preview: true,
          }),
        },
      );
      const telegramData = await telegramResponse.json() as JsonMap;
      if (!telegramResponse.ok || telegramData.ok !== true) {
        const description = String(
          telegramData.description ?? "Telegram не принял сообщение",
        );
        return response({ error: description }, 502);
      }
      const result = (telegramData.result ?? {}) as JsonMap;
      const telegramMessageId = Number(result.message_id ?? 0) || null;

      const { data: messageRow, error: messageError } = await admin
        .from("recruitment_messages")
        .insert({
          company_id: application.company_id,
          application_id: application.id,
          direction: "outbound",
          message_text: text,
          telegram_message_id: telegramMessageId,
          created_by: user.id,
        })
        .select("id,created_at")
        .single();
      if (messageError) throw messageError;

      if (application.status === "new" || application.status === "draft") {
        const now = new Date().toISOString();
        const { error: statusError } = await admin
          .from("recruitment_applications")
          .update({ status: "contacted", updated_at: now })
          .eq("id", application.id);
        if (statusError) throw statusError;
        await admin.from("recruitment_status_history").insert({
          company_id: application.company_id,
          application_id: application.id,
          status: "contacted",
          comment: "HR написал кандидату через Telegram-бота",
          source: "appstroy_hr",
          created_by: user.id,
        });
      }

      return response({ ok: true, message: messageRow });
    }

    if (action === "delete_application") {
      if (!application.archived_at) {
        return response({ error: "Сначала переместите заявку в архив" }, 409);
      }
      await removeStoredFiles(admin, application);
      const { error: deleteError } = await admin
        .from("recruitment_applications")
        .delete()
        .eq("id", application.id)
        .eq("company_id", application.company_id);
      if (deleteError) throw deleteError;
      return response({ ok: true });
    }

    return response({ error: "Неизвестное действие" }, 400);
  } catch (error) {
    console.error("recruitment candidate action failed", error);
    return response({
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});
