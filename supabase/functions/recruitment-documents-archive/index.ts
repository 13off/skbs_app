import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";
import JSZip from "npm:jszip@3.10.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const bucketName = "recruitment-documents";

type JsonMap = Record<string, unknown>;
type DocumentRow = {
  document_type: string;
  storage_bucket: string;
  storage_path: string;
  original_name: string;
  mime_type: string;
};

function json(body: unknown, status = 200) {
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

function safeFilePart(value: string, fallback: string): string {
  const clean = value
    .trim()
    .replace(/[^0-9A-Za-zА-Яа-яЁё]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 100);
  return clean || fallback;
}

function documentFilePrefix(type: string): string {
  switch (type) {
    case "passport_main":
      return "Паспорт";
    case "registration":
      return "Прописка";
    case "snils":
      return "СНИЛС";
    case "inn":
      return "ИНН";
    case "policy":
      return "Полис";
    default:
      return "Документ";
  }
}

function extension(row: DocumentRow): string {
  const fromName = row.original_name.split(".").at(-1)?.toLowerCase() ?? "";
  const fromPath = row.storage_path.split(".").at(-1)?.toLowerCase() ?? "";
  for (const value of [fromName, fromPath]) {
    if (["jpg", "jpeg", "png", "webp", "pdf"].includes(value)) {
      return value === "jpeg" ? "jpg" : value;
    }
  }
  if (row.mime_type === "application/pdf") return "pdf";
  if (row.mime_type === "image/png") return "png";
  if (row.mime_type === "image/webp") return "webp";
  return "jpg";
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

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Метод не поддерживается" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authorization = request.headers.get("Authorization") ?? "";
    const secret = serviceKey();
    if (!supabaseUrl || !anonKey || !authorization || !secret) {
      return json({ error: "Сервис не настроен" }, 500);
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
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const body = await request.json() as JsonMap;
    const applicationId = String(body.application_id ?? "").trim();
    if (!applicationId) {
      return json({ error: "Не указана заявка" }, 400);
    }

    const admin = createClient(supabaseUrl, secret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: application, error: applicationError } = await admin
      .from("recruitment_applications")
      .select("id,company_id,full_name")
      .eq("id", applicationId)
      .maybeSingle();
    if (applicationError) throw applicationError;
    if (!application) return json({ error: "Заявка не найдена" }, 404);

    const { data: membership, error: membershipError } = await admin
      .from("company_memberships")
      .select("role")
      .eq("company_id", application.company_id)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .in("role", ["owner", "admin", "hr"])
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return json({ error: "Нет доступа к документам" }, 403);

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
      return json({ error: "У кандидата пока нет загруженных документов" }, 409);
    }

    const zip = new JSZip();
    const usedNames = new Set<string>();
    for (let index = 0; index < documents.length; index += 1) {
      const row = documents[index];
      const { data: file, error: downloadError } = await admin.storage
        .from(row.storage_bucket)
        .download(row.storage_path);
      if (downloadError) throw downloadError;

      const ext = extension(row);
      const candidateName = safeFilePart(
        String(application.full_name ?? ""),
        "Кандидат",
      );
      let fileName = `${documentFilePrefix(row.document_type)}_${candidateName}.${ext}`;
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
      zip.file(fileName, new Uint8Array(await file.arrayBuffer()));
    }

    const archive = await zip.generateAsync({
      type: "uint8array",
      compression: "DEFLATE",
      compressionOptions: { level: 6 },
    });
    const archivePath =
      `${application.company_id}/${application.id}/exports/documents.zip`;
    const { error: uploadError } = await admin.storage
      .from(bucketName)
      .upload(archivePath, archive, {
        contentType: "application/zip",
        cacheControl: "300",
        upsert: true,
      });
    if (uploadError) throw uploadError;

    const fileName = `Документы_${safeFilePart(
      String(application.full_name ?? ""),
      "Кандидат",
    )}.zip`;
    const { data: signed, error: signedError } = await admin.storage
      .from(bucketName)
      .createSignedUrl(archivePath, 300, { download: fileName });
    if (signedError) throw signedError;

    return json({ ok: true, url: signed.signedUrl, count: documents.length });
  } catch (error) {
    console.error("recruitment documents archive failed", error);
    return json({
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});
