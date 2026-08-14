import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonMap = Record<string, unknown>;

type ChatRow = {
  id: string;
  company_id: string;
  sender_user_id: string | null;
  sender_name: string;
  kind: string;
  channel_kind: string;
  peer_user_id: string | null;
  thread_key: string;
  body: string;
  created_at: string;
  deleted_at: string | null;
  ai_payload?: JsonMap | null;
};

const APP_KNOWLEDGE = [
  "AppСтрой — рабочая система строительной компании. ИИ-помощник должен опираться на реальные данные активной компании и права текущей роли.",
  "Роли приложения: руководитель/администратор, разработчик, прораб, бухгалтер, HR, юрист, снабженец и сотрудник.",
  "Основные рабочие области: Главная и объекты; сотрудники; табель и смены; выплаты, авансы, остатки и чеки; отчёты; задачи; вехи, цели и чек-листы; кандидаты, этапы подбора, оформление, вылеты, билеты и кадровые документы; снабжение, заявки, материалы и поставщики; юридические вопросы, договоры, решения и риски; чат компании и личные диалоги; профиль, настройки и уведомления; рабочий день сотрудника, геолокация, задачи и фото; режимы ролей и диагностика разработчика.",
  "Для руководителя основные вкладки: Главная, Люди, Отчёты, Задачи, Профиль; из рабочих экранов также открываются Табель и Выплаты.",
  "Голос и письменный чат — два входа в один помощник. Операционные запросы и изменения должны проходить через общий маршрутизатор ai-global-command.",
  "Любые факты о сотрудниках, объектах, задачах, табеле, выплатах, кандидатах, снабжении и юридических данных нельзя выдумывать. Их нужно получать из доступных данных приложения.",
  "Любое изменение данных остаётся подготовленным действием и проходит штатную проверку/подтверждение. Никогда не утверждай, что запись уже изменена, если подтверждение не выполнено.",
].join("\n");

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

function clean(value: unknown, max = 5000): string {
  return String(value ?? "").trim().slice(0, max);
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

function resultText(result: JsonMap): string {
  const title = clean(result.title, 240);
  const summary = clean(result.summary, 6000);
  const highlights = Array.isArray(result.highlights)
    ? result.highlights.map((item) => clean(item, 500)).filter(Boolean)
    : [];
  const warnings = Array.isArray(result.warnings)
    ? result.warnings.map((item) => clean(item, 500)).filter(Boolean)
    : [];
  const nextSteps = Array.isArray(result.next_steps)
    ? result.next_steps.map((item) => clean(item, 500)).filter(Boolean)
    : [];
  const parts = [
    title,
    summary,
    highlights.length ? highlights.map((item) => `• ${item}`).join("\n") : "",
    warnings.length ? `Важно:\n${warnings.map((item) => `• ${item}`).join("\n")}` : "",
    nextSteps.length ? `Дальше:\n${nextSteps.map((item) => `• ${item}`).join("\n")}` : "",
  ].filter(Boolean);
  return parts.join("\n\n").slice(0, 6000) || "Помощник не вернул текстовый ответ.";
}

function outputText(payload: any): string {
  if (typeof payload?.output_text === "string") return payload.output_text.trim();
  const output = Array.isArray(payload?.output) ? payload.output : [];
  for (const item of output) {
    if (item?.type !== "message" || !Array.isArray(item?.content)) continue;
    for (const part of item.content) {
      if (part?.type === "output_text" && typeof part?.text === "string") {
        return part.text.trim();
      }
    }
  }
  return "";
}

function mapValue(value: unknown): JsonMap {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return {};
}

function conversationContext(recent: ChatRow[], source: ChatRow): JsonMap {
  const prior = recent.filter((item) => item.id !== source.id);
  const lastAssistant = [...prior].reverse().find((item) => item.kind === "assistant");
  const payload = mapValue(lastAssistant?.ai_payload);
  const conversation = mapValue(payload.conversation);
  const previousUser = [...prior].reverse().find((item) => item.kind === "user");

  const topic = clean(conversation.topic, 100);
  const queryMode = clean(conversation.query_mode, 60);
  const objectName = clean(conversation.object_name, 180);
  const date = clean(conversation.date, 32);
  const previousPrompt = clean(conversation.prompt, 1200) || clean(previousUser?.body, 1200);

  const result: JsonMap = {};
  if (topic) result.topic = topic;
  if (queryMode) result.query_mode = queryMode;
  if (objectName) result.object_name = objectName;
  if (date) result.date = date;
  if (previousPrompt) result.prompt = previousPrompt;
  return result;
}

async function invokeGlobalAssistant({
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
}): Promise<{ data: JsonMap; status: number }> {
  const response = await fetch(`${supabaseUrl}/functions/v1/ai-global-command`, {
    method: "POST",
    headers: {
      "Authorization": authorization,
      "apikey": publishable,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      company_id: companyId,
      object_name: objectName || null,
      date: new Date().toISOString().slice(0, 10),
      prompt,
      conversation_context: context,
      input_mode: "chat",
    }),
  });
  return {
    data: await response.json().catch(() => ({})) as JsonMap,
    status: response.status,
  };
}

async function appAwareFreeform({
  role,
  objectName,
  history,
  prompt,
}: {
  role: string;
  objectName: string;
  history: ChatRow[];
  prompt: string;
}): Promise<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "";
  if (!apiKey) {
    return "Не удалось обработать свободный вопрос. Операционные команды AppСтрой при этом продолжают работать через общий ИИ-маршрутизатор.";
  }
  const model = Deno.env.get("OPENAI_MODEL")?.trim() || "gpt-5-mini";
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20_000);
  try {
    const recentMessages = history
      .filter((item) => item.body.trim())
      .slice(-10)
      .map((item) => ({
        role: item.kind === "assistant" ? "assistant" : "user",
        content: item.body.slice(0, 1200),
      }));
    const input = [
      {
        role: "developer",
        content: [
          "Ты единый ИИ-помощник AppСтрой. Сейчас пользователь пишет тебе текстом в личном чате, но твои знания и правила должны совпадать с голосовым помощником.",
          APP_KNOWLEDGE,
          `Текущая роль: ${role || "не указана"}.`,
          objectName ? `Текущий объект: ${objectName}.` : "Текущий объект явно не выбран.",
          "Этот свободный режим используется только когда общий операционный маршрутизатор не распознал действие. Отвечай на вопросы об устройстве и работе AppСтрой, объясняй возможности и помогай сформулировать команду.",
          "Если пользователь просит конкретный факт из живых данных компании, которого нет в переданном контексте, не выдумывай его. Скажи, какой запрос лучше задать помощнику, чтобы он прочитал данные приложения.",
          "Не сообщай, что изменение данных выполнено. Записи меняются только через подтверждаемое действие AppСтрой.",
          "Отвечай по-русски, коротко и по делу.",
        ].join("\n\n"),
      },
      ...recentMessages,
      { role: "user", content: prompt.slice(0, 4000) },
    ];

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ model, input }),
      signal: controller.signal,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload?.error?.message || `OpenAI API error ${response.status}`);
    }
    return outputText(payload) || "Не получилось сформировать ответ. Попробуй переформулировать запрос.";
  } finally {
    clearTimeout(timer);
  }
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
      return json({ error: "Сервис ИИ чата не настроен" }, 500);
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
      return json({ error: "Не указано сообщение для ответа ИИ" }, 400);
    }

    const [{ data: canUseAi, error: aiPermissionError }, { data: canViewChat, error: chatPermissionError }] = await Promise.all([
      userClient.rpc("current_user_has_permission", { p_permission_code: "ai.use" }),
      userClient.rpc("current_user_has_permission", { p_permission_code: "company_chat.view" }),
    ]);
    if (aiPermissionError) throw aiPermissionError;
    if (chatPermissionError) throw chatPermissionError;
    if (canUseAi !== true) return json({ error: "Для этой роли ИИ-помощник отключён" }, 403);
    if (canViewChat !== true) return json({ error: "Нет доступа к чатам" }, 403);

    const admin: any = createClient(supabaseUrl, secret, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: membership, error: membershipError } = await admin
      .from("company_memberships")
      .select("company_id,role,is_active")
      .eq("company_id", companyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return json({ error: "Нет активного доступа к компании" }, 403);
    const role = clean(membership.role, 40);

    const { data: sourceData, error: sourceError } = await admin
      .from("company_chat_messages")
      .select("id,company_id,sender_user_id,sender_name,kind,channel_kind,peer_user_id,thread_key,body,created_at,deleted_at,ai_payload")
      .eq("company_id", companyId)
      .eq("id", sourceMessageId)
      .maybeSingle();
    if (sourceError) throw sourceError;
    const source = sourceData as ChatRow | null;
    if (!source || source.deleted_at || source.kind !== "user") {
      return json({ error: "Исходное сообщение недоступно" }, 404);
    }
    if (source.sender_user_id !== user.id) {
      return json({ error: "ИИ может отвечать только на твой запрос" }, 403);
    }
    if (source.channel_kind !== "assistant" || source.peer_user_id !== user.id) {
      return json({ error: "Открой раздел ИИ-помощника и отправь запрос там" }, 400);
    }

    const { data: existing } = await admin
      .from("company_chat_messages")
      .select("id")
      .eq("company_id", companyId)
      .eq("thread_key", source.thread_key)
      .eq("kind", "assistant")
      .eq("reply_to_id", sourceMessageId)
      .is("deleted_at", null)
      .maybeSingle();
    if (existing?.id) return json({ ok: true, message_id: existing.id, duplicate: true });

    const recentThreshold = new Date(Date.now() - 10_000).toISOString();
    const { count: recentCount, error: rateError } = await admin
      .from("company_chat_messages")
      .select("id", { count: "exact", head: true })
      .eq("company_id", companyId)
      .eq("thread_key", source.thread_key)
      .eq("kind", "assistant")
      .eq("ai_requester_user_id", user.id)
      .gte("created_at", recentThreshold);
    if (rateError) throw rateError;
    if ((recentCount ?? 0) >= 2) {
      return json({ error: "Подожди несколько секунд перед следующим запросом к ИИ" }, 429);
    }

    const { data: recentData, error: recentError } = await admin
      .from("company_chat_messages")
      .select("id,company_id,sender_user_id,sender_name,kind,channel_kind,peer_user_id,thread_key,body,created_at,deleted_at,ai_payload")
      .eq("company_id", companyId)
      .eq("thread_key", source.thread_key)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(18);
    if (recentError) throw recentError;
    const recent = ((recentData ?? []) as ChatRow[]).reverse();
    const context = conversationContext(recent, source);

    const global = await invokeGlobalAssistant({
      supabaseUrl,
      publishable,
      authorization,
      companyId,
      objectName,
      prompt: source.body,
      context,
    });
    let aiData = global.data;
    let route = "ai-global-command";
    const globalError = clean(aiData.error, 1000);
    if (global.status < 200 || global.status >= 300 || globalError) {
      return json({ error: globalError || "ИИ-помощник временно недоступен" }, global.status || 500);
    }

    if (aiData.fallback === true) {
      const freeformHistory = recent.filter((item) => item.id !== source.id);
      const answer = await appAwareFreeform({
        role,
        objectName,
        history: freeformHistory,
        prompt: source.body,
      });
      aiData = {
        title: "ИИ-помощник AppСтрой",
        summary: answer,
        highlights: [],
        warnings: [],
        next_steps: [],
        scope_label: objectName ? `Объект: ${objectName}` : "Активная компания",
        preliminary: false,
        ai_used: true,
        assistant_mode: "app_freeform",
        app_knowledge_version: 1,
      };
      route = "ai-global-command+openai-freeform";
    }

    const storedPayload: JsonMap = {
      ...aiData,
      input_mode: "chat",
      unified_assistant: true,
    };

    const { data: inserted, error: insertError } = await admin
      .from("company_chat_messages")
      .insert({
        company_id: companyId,
        sender_user_id: null,
        sender_name: "ИИ-помощник AppСтрой",
        sender_role: "ai",
        kind: "assistant",
        channel_kind: "assistant",
        peer_user_id: user.id,
        thread_key: source.thread_key,
        body: resultText(storedPayload),
        reply_to_id: sourceMessageId,
        mentioned_user_ids: [user.id],
        ai_payload: storedPayload,
        ai_requester_user_id: user.id,
      })
      .select("id")
      .single();
    if (insertError?.code === "23505") {
      const { data: duplicate } = await admin
        .from("company_chat_messages")
        .select("id")
        .eq("company_id", companyId)
        .eq("thread_key", source.thread_key)
        .eq("kind", "assistant")
        .eq("reply_to_id", sourceMessageId)
        .is("deleted_at", null)
        .maybeSingle();
      return json({ ok: true, message_id: duplicate?.id ?? "", duplicate: true });
    }
    if (insertError) throw insertError;

    return json({ ok: true, message_id: inserted.id, function: route });
  } catch (error) {
    console.error("company-chat-ai failed", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
