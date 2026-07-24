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
  position_title: string;
  object_name: string;
  source: string;
  external_chat_id: string;
  responsible_user_id: string | null;
  stage_id: string;
  updated_at: string;
  created_at: string;
  archived_at: string | null;
};

type RuleRow = {
  id: string;
  company_id: string;
  trigger_stage_id: string;
  title: string;
  action_type: string;
  task_title: string;
  task_type: string;
  task_priority: string;
  due_offset_hours: number;
  message_text: string;
  assigned_to: string | null;
};

function renderTemplate(template: string, application: ApplicationRow): string {
  return template
    .replaceAll("{candidate}", application.full_name)
    .replaceAll("{кандидат}", application.full_name)
    .replaceAll("{name}", application.full_name)
    .replaceAll("{vacancy}", application.position_title || "")
    .replaceAll("{object}", application.object_name || "")
    .trim();
}

async function sendTelegramMessage(
  admin: any,
  application: ApplicationRow,
  text: string,
  actorUserId: string,
) {
  if (application.source !== "telegram" || !application.external_chat_id) {
    return { sent: false, reason: "Кандидат недоступен через Telegram" };
  }
  const token = botToken();
  if (!token) return { sent: false, reason: "Токен Telegram-бота не подключён" };

  const telegramResponse = await fetch(
    `https://api.telegram.org/bot${token}/sendMessage`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: application.external_chat_id,
        text: text.slice(0, 3500),
        disable_web_page_preview: true,
      }),
    },
  );
  const telegramData = await telegramResponse.json() as JsonMap;
  if (!telegramResponse.ok || telegramData.ok !== true) {
    return {
      sent: false,
      reason: String(telegramData.description ?? "Telegram не принял сообщение"),
    };
  }

  const result = (telegramData.result ?? {}) as JsonMap;
  const telegramMessageId = Number(result.message_id ?? 0) || null;
  const { error } = await admin.from("recruitment_messages").insert({
    company_id: application.company_id,
    application_id: application.id,
    direction: "outbound",
    message_text: text.slice(0, 3500),
    telegram_message_id: telegramMessageId,
    created_by: actorUserId,
  });
  if (error) throw error;
  return { sent: true };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response({ error: "Метод не поддерживается" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const secret = serviceKey();
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !secret || !authorization) {
      return response({ error: "Сервис автоматизаций не настроен" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return response({ error: "Требуется повторный вход" }, 401);

    const body = await request.json() as JsonMap;
    const rawIds = Array.isArray(body.application_ids) ? body.application_ids : [];
    const applicationIds = [...new Set(rawIds.map((value) => String(value).trim()).filter(Boolean))]
      .slice(0, 100);
    if (!applicationIds.length) return response({ error: "Не выбраны кандидаты" }, 400);

    const admin: any = createClient(supabaseUrl, secret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: applicationsData, error: applicationsError } = await admin
      .from("recruitment_applications")
      .select("id,company_id,full_name,position_title,source,external_chat_id,responsible_user_id,stage_id,updated_at,created_at,archived_at,objects(name)")
      .in("id", applicationIds)
      .is("archived_at", null);
    if (applicationsError) throw applicationsError;
    const applications: ApplicationRow[] = (applicationsData ?? []).map((raw: JsonMap) => {
      const row = raw as JsonMap;
      const objectRaw = row.objects;
      const objectRelation = Array.isArray(objectRaw)
        ? (objectRaw[0] as JsonMap | undefined)
        : (objectRaw as JsonMap | null);
      return {
        ...row,
        object_name: String(objectRelation?.name ?? ""),
      } as unknown as ApplicationRow;
    });
    if (!applications.length) return response({ error: "Кандидаты не найдены" }, 404);

    const companyIds = [...new Set(applications.map((item) => item.company_id))];
    const { data: memberships, error: membershipError } = await admin
      .from("company_memberships")
      .select("company_id,role,is_active")
      .eq("user_id", user.id)
      .eq("is_active", true)
      .in("company_id", companyIds)
      .in("role", ["owner", "admin", "developer", "hr"]);
    if (membershipError) throw membershipError;
    const allowedCompanies = new Set((memberships ?? []).map((row: JsonMap) => String(row.company_id)));
    const allowedApplications = applications.filter((item) => allowedCompanies.has(item.company_id));
    if (!allowedApplications.length) return response({ error: "Нет доступа к кандидатам" }, 403);

    const stageIds = [...new Set(allowedApplications.map((item) => item.stage_id).filter(Boolean))];
    const { data: rulesData, error: rulesError } = await admin
      .from("recruitment_crm_automation_rules")
      .select("id,company_id,trigger_stage_id,title,action_type,task_title,task_type,task_priority,due_offset_hours,message_text,assigned_to")
      .in("company_id", [...allowedCompanies])
      .in("trigger_stage_id", stageIds)
      .eq("is_active", true)
      .order("sort_order");
    if (rulesError) throw rulesError;
    const rules = (rulesData ?? []) as RuleRow[];

    const { data: histories, error: historiesError } = await admin
      .from("recruitment_status_history")
      .select("application_id,stage_id,created_at")
      .in("application_id", allowedApplications.map((item) => item.id))
      .order("created_at", { ascending: false });
    if (historiesError) throw historiesError;
    const latestTransition = new Map<string, string>();
    for (const row of histories ?? []) {
      const applicationId = String(row.application_id ?? "");
      if (!latestTransition.has(applicationId)) {
        latestTransition.set(applicationId, String(row.created_at ?? ""));
      }
    }

    let tasksCreated = 0;
    let messagesSent = 0;
    let skipped = 0;
    const errors: JsonMap[] = [];

    for (const application of allowedApplications) {
      const transitionAt = latestTransition.get(application.id) || application.created_at || application.updated_at;
      const matchingRules = rules.filter((rule) =>
        rule.company_id === application.company_id && rule.trigger_stage_id === application.stage_id
      );
      for (const rule of matchingRules) {
        const { data: run, error: runError } = await admin
          .from("recruitment_crm_automation_runs")
          .insert({
            company_id: application.company_id,
            rule_id: rule.id,
            application_id: application.id,
            application_updated_at: transitionAt,
            status: "processing",
          })
          .select("id")
          .maybeSingle();
        if (runError?.code === "23505") {
          skipped++;
          continue;
        }
        if (runError || !run) throw runError ?? new Error("Не удалось создать запуск автоматизации");

        const runResult: JsonMap = {};
        try {
          if (rule.action_type === "create_task" || rule.action_type === "create_task_and_message") {
            const taskTitle = renderTemplate(rule.task_title || rule.title, application) || rule.title;
            const dueAt = new Date(Date.now() + Math.max(0, rule.due_offset_hours) * 3600000).toISOString();
            const { error: taskError } = await admin.from("recruitment_crm_tasks").insert({
              company_id: application.company_id,
              application_id: application.id,
              title: taskTitle,
              description: `Автоматизация: ${rule.title}`,
              task_type: rule.task_type || "other",
              priority: rule.task_priority || "normal",
              due_at: dueAt,
              assigned_to: rule.assigned_to || application.responsible_user_id || user.id,
              created_by: user.id,
            });
            if (taskError) throw taskError;
            tasksCreated++;
            runResult.task_created = true;
          }

          if (rule.action_type === "send_message" || rule.action_type === "create_task_and_message") {
            const message = renderTemplate(rule.message_text, application);
            if (message) {
              const messageResult = await sendTelegramMessage(admin, application, message, user.id);
              runResult.message = messageResult;
              if (messageResult.sent) messagesSent++;
            } else {
              runResult.message = { sent: false, reason: "Текст сообщения пуст" };
            }
          }

          await admin.from("recruitment_crm_automation_runs").update({
            status: "completed",
            result: runResult,
            completed_at: new Date().toISOString(),
          }).eq("id", run.id);
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          errors.push({ application_id: application.id, rule_id: rule.id, error: message });
          await admin.from("recruitment_crm_automation_runs").update({
            status: "failed",
            result: { error: message },
            completed_at: new Date().toISOString(),
          }).eq("id", run.id);
        }
      }
    }

    return response({
      ok: true,
      candidates: allowedApplications.length,
      tasks_created: tasksCreated,
      messages_sent: messagesSent,
      skipped,
      errors,
    });
  } catch (error) {
    console.error("run-recruitment-crm-automations failed", error);
    return response({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
