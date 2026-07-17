import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

async function removeStoredFiles(
  admin: ReturnType<typeof createClient>,
  applicationId: string,
) {
  const [
    { data: documents, error: documentsError },
    { data: messages, error: messagesError },
  ] = await Promise.all([
    admin
      .from("recruitment_documents")
      .select("storage_bucket,storage_path")
      .eq("application_id", applicationId),
    admin
      .from("recruitment_messages")
      .select("storage_bucket,storage_path")
      .eq("application_id", applicationId),
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
      await removeStoredFiles(admin, application.id);
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
