import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonMap = Record<string, unknown>;

type ChatRow = {
  id: string;
  sender_user_id: string | null;
  kind: string;
  channel_kind: string;
  peer_user_id: string | null;
  thread_key: string;
  body: string;
  deleted_at: string | null;
  ai_payload?: JsonMap | null;
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

function clean(value: unknown, max = 6000): string {
  return String(value ?? "").trim().slice(0, max);
}

function mapValue(value: unknown): JsonMap {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return {};
}

function normalize(value: unknown): string {
  return clean(value, 12000)
    .toLowerCase()
    .replaceAll("ё", "е")
    .replace(/[^а-яa-z0-9.,:+\-\/ ]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
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

function publishableKey(): string {
  const legacy = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
  if (legacy) return legacy;
  const direct = Deno.env.get("SUPABASE_PUBLISHABLE_KEY")?.trim() ?? "";
  if (direct) return direct;
  const modern = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, string>;
      return parsed.default ?? Object.values(parsed)[0] ?? "";
    } catch (_) {}
  }
  return "";
}

function isFunctionalRequest(prompt: string): boolean {
  const value = normalize(prompt);
  const direct = /(?:скач|выгруз|экспорт|таблиц|xlsx|excel|сформир|сохрани\s+файл|скин\s+файл|скин\s+таблиц|пришл.*файл)/.test(value);
  if (direct) return true;
  const verb = /(?:созда|добав|сохран|запол|простав|постав|отмет|измен|исправ|назнач|перевед|отправ|удал|архив|восстанов|подготов|открой|запиш|провед|сдел)/.test(value);
  const domain = /(?:табел|смен|выплат|аванс|остатк|долг|зарплат|задач|сотрудник|работник|кандидат|соискател|документ|таблиц|отчет|снабжен|закуп|поставщик|объект|вех|цел|чек|билет|вылет|юрид|претенз|акт|уведом|профил|геолокац|рабоч.*день)/.test(value);
  return verb && domain;
}

function requestedMonth(prompt: string): string {
  const value = normalize(prompt);
  const iso = value.match(/\b(20\d{2})[-./](0?[1-9]|1[0-2])\b/);
  if (iso) return `${iso[1]}-${String(Number(iso[2])).padStart(2, "0")}`;

  const names: Array<[RegExp, number]> = [
    [/январ/, 1], [/феврал/, 2], [/март/, 3], [/апрел/, 4], [/ма[йя]/, 5],
    [/июн/, 6], [/июл/, 7], [/август/, 8], [/сентябр/, 9], [/октябр/, 10],
    [/ноябр/, 11], [/декабр/, 12],
  ];
  const yearMatch = value.match(/\b(20\d{2})\b/);
  const year = yearMatch ? Number(yearMatch[1]) : new Date().getFullYear();
  for (const [pattern, month] of names) {
    if (pattern.test(value)) return `${year}-${String(month).padStart(2, "0")}`;
  }
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

function reportType(value: string): string {
  if (/(?:поставщик)/.test(value)) return "suppliers";
  if (/(?:вылет|рейс|билет|прилет)/.test(value)) return "flights";
  if (/(?:кандидат|соискател|подбор|кадр)/.test(value)) return "candidates";
  if (/(?:снабжен|закуп|заявк|поставк)/.test(value)) return "procurement";
  if (/(?:задач|наряд|работ)/.test(value)) return "tasks";
  if (/(?:сотрудник|работник|бригада|персонал)/.test(value)) return "employees";
  return "";
}

function actionLabel(type: string, action: JsonMap): string {
  const screen = clean(mapValue(action.payload).screen, 80);
  const labels: Record<string, string> = {
    create_task_draft: "Проверить и создать задачу",
    prepare_timesheet_correction: "Проверить и сохранить табель",
    bulk_timesheet_update: "Проверить и сохранить табель",
    prepare_payment: "Проверить и сохранить выплату",
    prepare_document: "Проверить и скачать документ",
    prepare_work_act: "Проверить и сформировать акт",
    create_employee_draft: "Проверить и добавить сотрудника",
    prepare_employee_update: "Проверить и сохранить сотрудника",
    create_procurement_request: "Проверить и создать заявку",
    create_legal_matter: "Проверить и создать вопрос",
    assign_candidate_responsible: "Проверить и назначить",
    send_candidate_message: "Проверить и отправить сообщение",
    open_period_timesheet: "Открыть таблицу табеля",
    open_candidate_detail: "Открыть кандидата",
    download_timesheet_excel: "Скачать таблицу табеля",
    download_payment_report: "Скачать таблицу выплат",
    download_appstroy_table: "Скачать XLSX",
  };
  if (labels[type]) return labels[type];
  if (type === "open_screen") {
    const byScreen: Record<string, string> = {
      payments: "Открыть выплаты",
      timesheet: "Открыть табель",
      tasks: "Открыть задачи",
      employees: "Открыть сотрудников",
      recruitment: "Открыть кандидатов",
      procurement: "Открыть снабжение",
      suppliers: "Открыть поставщиков",
      legal: "Открыть юридический раздел",
      milestones: "Открыть цели",
      notifications: "Открыть уведомления",
      settings: "Открыть настройки",
      tools: "Открыть инструменты",
    };
    return byScreen[screen] ?? "Открыть в AppСтрой";
  }
  return clean(action.button_label, 100) || "Проверить действие";
}

function isDirectDownload(type: string): boolean {
  return type === "download_timesheet_excel" ||
    type === "download_payment_report" ||
    type === "download_appstroy_table";
}

function normalizeAction(action: JsonMap, sourceMessageId: string): JsonMap {
  const type = clean(action.type, 100);
  if (!type) return {};
  const clickIsConfirmation = new Set([
    "open_screen",
    "open_candidate_detail",
    "download_timesheet_excel",
    "download_payment_report",
    "download_appstroy_table",
  ]).has(type);
  return {
    ...action,
    id: clean(action.id, 160) || `chatgpt-action-${sourceMessageId}`,
    type,
    title: clean(action.title, 240) || "Действие AppСтрой",
    button_label: actionLabel(type, action),
    confirmation_required: clickIsConfirmation
      ? false
      : action.confirmation_required !== false,
    payload: mapValue(action.payload),
  };
}

function fallbackAction({
  prompt,
  sourceMessageId,
  objectName,
  topic,
  contextText,
}: {
  prompt: string;
  sourceMessageId: string;
  objectName: string;
  topic: string;
  contextText: string;
}): JsonMap {
  // Контекст нужен для коротких продолжений вроде «сам таблицу сделай».
  const combined = `${contextText}\n${topic}\n${prompt}`;
  const value = normalize(combined);
  const exportLike = /(?:скач|выгруз|экспорт|таблиц|отчет|xlsx|excel|файл)/.test(normalize(prompt)) ||
    /(?:сам\s+сделай|сделай\s+сам|пришли|скинь)/.test(normalize(prompt)) &&
      /(?:таблиц|xlsx|excel|выгруз)/.test(value);
  const paymentDomain = /(?:выплат|аванс|остатк|долг|зарплат|чек|расчетн)/.test(value);
  const timesheetDomain = /(?:табел|смен|выход|явк)/.test(value);

  if (exportLike && paymentDomain) {
    return {
      id: `chatgpt-payment-export-${sourceMessageId}`,
      type: "download_payment_report",
      title: `Скачать таблицу выплат за ${requestedMonth(combined)}`,
      button_label: "Скачать таблицу выплат",
      confirmation_required: false,
      payload: {
        month: requestedMonth(combined),
        object_name: objectName || null,
        source: "chatgpt_function_bridge",
      },
    };
  }

  if (exportLike && timesheetDomain) {
    return {
      id: `chatgpt-timesheet-export-${sourceMessageId}`,
      type: "download_timesheet_excel",
      title: `Скачать табель за ${requestedMonth(combined)}`,
      button_label: "Скачать таблицу табеля",
      confirmation_required: false,
      payload: {
        month: requestedMonth(combined),
        object_name: objectName || null,
        source: "chatgpt_function_bridge",
      },
    };
  }

  const genericType = reportType(value);
  if (exportLike && genericType) {
    return {
      id: `chatgpt-generic-export-${genericType}-${sourceMessageId}`,
      type: "download_appstroy_table",
      title: "Скачать таблицу из AppСтрой",
      button_label: "Скачать XLSX",
      confirmation_required: false,
      payload: {
        report_type: genericType,
        month: requestedMonth(combined),
        object_name: objectName || null,
        source: "chatgpt_function_bridge",
      },
    };
  }

  let screen = "tools";
  let title = "Открыть инструменты AppСтрой";
  if (paymentDomain) {
    screen = "payments";
    title = "Открыть выплаты";
  } else if (timesheetDomain) {
    screen = "timesheet";
    title = "Открыть табель";
  } else if (/(?:задач|наряд|работ)/.test(value)) {
    screen = "tasks";
    title = "Открыть задачи";
  } else if (/(?:сотрудник|работник|бригада)/.test(value)) {
    screen = "employees";
    title = "Открыть сотрудников";
  } else if (/(?:кандидат|соискател|подбор|кадр)/.test(value)) {
    screen = "recruitment";
    title = "Открыть кандидатов";
  } else if (/(?:поставщик)/.test(value)) {
    screen = "suppliers";
    title = "Открыть поставщиков";
  } else if (/(?:снабжен|закуп|заявк)/.test(value)) {
    screen = "procurement";
    title = "Открыть снабжение";
  } else if (/(?:юрид|претенз|иск|договор)/.test(value)) {
    screen = "legal";
    title = "Открыть юридический раздел";
  } else if (/(?:вех|цел)/.test(value)) {
    screen = "milestones";
    title = "Открыть цели";
  } else if (/(?:уведом)/.test(value)) {
    screen = "notifications";
    title = "Открыть уведомления";
  } else if (/(?:настрой|профил)/.test(value)) {
    screen = "settings";
    title = "Открыть настройки";
  }

  return {
    id: `chatgpt-fallback-${sourceMessageId}`,
    type: "open_screen",
    title,
    button_label: title,
    confirmation_required: false,
    payload: {
      screen,
      object_name: objectName || null,
      source: "chatgpt_function_fallback",
    },
  };
}

async function invokeAppStroy({
  supabaseUrl,
  publishable,
  authorization,
  companyId,
  objectName,
  prompt,
  context,
}: {
  supabaseUrl: string;
  publishable: string;
  authorization: string;
  companyId: string;
  objectName: string;
  prompt: string;
  context: JsonMap;
}) {
  const response = await fetch(`${supabaseUrl}/functions/v1/ai-global-command`, {
    method: "POST",
    headers: {
      Authorization: authorization,
      apikey: publishable,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      company_id: companyId,
      object_name: objectName || null,
      date: new Date().toISOString().slice(0, 10),
      prompt,
      conversation_context: context,
      input_mode: "chatgpt_action_prepare",
    }),
  });
  return {
    status: response.status,
    data: await response.json().catch(() => ({})) as JsonMap,
  };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Метод не поддерживается" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const publishable = publishableKey();
    const secret = serviceKey();
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !publishable || !secret || !authorization) {
      return json({ error: "Мост действий ChatGPT не настроен" }, 500);
    }

    const userClient = createClient(supabaseUrl, publishable, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser();
    const user = authData.user;
    if (authError || !user) return json({ error: "Требуется повторный вход" }, 401);

    const input = await request.json().catch(() => ({})) as JsonMap;
    const companyId = clean(input.company_id, 80);
    const sourceMessageId = clean(input.source_message_id, 80);
    const objectName = clean(input.object_name, 180);
    if (!companyId || !sourceMessageId) {
      return json({ error: "Не указан запрос ChatGPT" }, 400);
    }

    const admin: any = createClient(supabaseUrl, secret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: membership, error: membershipError } = await admin
      .from("company_memberships")
      .select("company_id,is_active")
      .eq("company_id", companyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return json({ error: "Нет активного доступа к компании" }, 403);

    const { data: sourceData, error: sourceError } = await admin
      .from("company_chat_messages")
      .select("id,sender_user_id,kind,channel_kind,peer_user_id,thread_key,body,deleted_at,ai_payload")
      .eq("company_id", companyId)
      .eq("id", sourceMessageId)
      .maybeSingle();
    if (sourceError) throw sourceError;
    const source = sourceData as ChatRow | null;
    if (!source || source.deleted_at || source.kind !== "user" || source.sender_user_id !== user.id) {
      return json({ error: "Исходный запрос недоступен" }, 404);
    }
    if (source.channel_kind !== "assistant" || source.peer_user_id !== user.id) {
      return json({ error: "Это не диалог ChatGPT" }, 400);
    }

    const { data: recentData, error: recentError } = await admin
      .from("company_chat_messages")
      .select("id,kind,body")
      .eq("company_id", companyId)
      .eq("thread_key", source.thread_key)
      .is("deleted_at", null)
      .neq("id", sourceMessageId)
      .order("created_at", { ascending: false })
      .limit(10);
    if (recentError) throw recentError;
    const contextText = ((recentData ?? []) as Array<{ kind?: string; body?: string }>)
      .reverse()
      .map((item) => clean(item.body, 1000))
      .filter(Boolean)
      .join("\n");

    if (!isFunctionalRequest(`${contextText}\n${source.body}`)) {
      return json({ ok: true, functional: false });
    }

    const { data: assistantData, error: assistantError } = await admin
      .from("company_chat_messages")
      .select("id,sender_user_id,kind,channel_kind,peer_user_id,thread_key,body,deleted_at,ai_payload")
      .eq("company_id", companyId)
      .eq("thread_key", source.thread_key)
      .eq("kind", "assistant")
      .eq("reply_to_id", sourceMessageId)
      .is("deleted_at", null)
      .maybeSingle();
    if (assistantError) throw assistantError;
    const assistant = assistantData as ChatRow | null;
    if (!assistant) return json({ error: "Ответ ChatGPT ещё не создан" }, 409);

    const existingPayload = mapValue(assistant.ai_payload);
    const context = mapValue(existingPayload.conversation);
    const topic = clean(context.topic, 100);
    const fallback = normalizeAction(
      fallbackAction({
        prompt: source.body,
        sourceMessageId,
        objectName,
        topic,
        contextText,
      }),
      sourceMessageId,
    );
    const fallbackType = clean(fallback.type, 100);

    const existingAction = mapValue(existingPayload.action);
    if (Object.keys(existingAction).length > 0) {
      const normalizedExisting = normalizeAction(existingAction, sourceMessageId);
      const existingType = clean(normalizedExisting.type, 100);
      const preferred = isDirectDownload(fallbackType) && !isDirectDownload(existingType)
        ? fallback
        : normalizedExisting;
      if (JSON.stringify(preferred) !== JSON.stringify(existingAction)) {
        await admin
          .from("company_chat_messages")
          .update({ ai_payload: { ...existingPayload, action: preferred } })
          .eq("id", assistant.id);
      }
      return json({
        ok: true,
        functional: true,
        action_ready: true,
        reused: preferred === normalizedExisting,
        action_type: clean(preferred.type, 100),
      });
    }

    const appResult = await invokeAppStroy({
      supabaseUrl,
      publishable,
      authorization,
      companyId,
      objectName,
      prompt: source.body,
      context,
    });
    const appAction = mapValue(appResult.data.action);
    const appConversation = mapValue(appResult.data.conversation);
    const appPrepared = Object.keys(appAction).length > 0
      ? normalizeAction(appAction, sourceMessageId)
      : {};
    const appType = clean(appPrepared.type, 100);

    // Для выгрузки «открыть раздел» слабее реального XLSX. Не даём старому
    // маршруту понизить действие, которое клиент уже умеет выполнить сам.
    const prepared = isDirectDownload(fallbackType) && !isDirectDownload(appType)
      ? fallback
      : Object.keys(appPrepared).length > 0
      ? appPrepared
      : fallback;

    const nextPayload: JsonMap = {
      ...existingPayload,
      action: prepared,
      function_request: true,
      action_bridge: true,
      app_action_status: appResult.status,
    };
    if (Object.keys(appConversation).length > 0) nextPayload.conversation = appConversation;
    const semanticRoute = mapValue(appResult.data.semantic_route);
    if (Object.keys(semanticRoute).length > 0) nextPayload.semantic_route = semanticRoute;

    let nextBody = clean(assistant.body, 6000);
    const note = isDirectDownload(clean(prepared.type, 100))
      ? "Выгрузка готова — нажми кнопку ниже, и AppСтрой сам сформирует XLSX из актуальных данных."
      : "Действие AppСтрой подготовлено — проверь параметры и нажми кнопку ниже.";
    if (!nextBody.includes(note)) {
      nextBody = `${nextBody}${nextBody ? "\n\n" : ""}${note}`;
    }

    const { error: updateError } = await admin
      .from("company_chat_messages")
      .update({ body: nextBody.slice(0, 6000), ai_payload: nextPayload })
      .eq("id", assistant.id);
    if (updateError) throw updateError;

    return json({
      ok: true,
      functional: true,
      action_ready: true,
      action_type: clean(prepared.type, 100),
      app_status: appResult.status,
    });
  } catch (error) {
    console.error("company-chat-action-preparer failed", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
