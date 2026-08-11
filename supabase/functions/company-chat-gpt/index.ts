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

const CHATGPT_CUTOVER = "2026-08-11T11:19:00.000Z";

const APP_KNOWLEDGE = [
  "Ты ChatGPT внутри AppСтрой — рабочего приложения строительной компании.",
  "Разговаривай с пользователем как обычный ChatGPT, но для живых данных и действий AppСтрой используй инструмент appstroy_command.",
  "В AppСтрой есть: объекты, сотрудники, табель и смены, выплаты/авансы/остатки/чеки, отчёты, задачи, вехи и цели, кандидаты и оформление, билеты и вылеты, кадровые документы, снабжение и поставщики, юридический блок, чат, профиль, уведомления, рабочий день и геолокация.",
  "Права определяются ролью текущего пользователя. Инструмент AppСтрой сам проверяет компанию, роль и доступный объект.",
  "Если вопрос требует фактов из текущей компании — ФИО, суммы, смены, остатки, статусы, задачи, кандидаты, документы, заявки, поставщики, объект — обязательно вызови appstroy_command. Не угадывай живые данные.",
  "Если пользователь просит изменить данные, вызвать действие, создать задачу, изменить табель, выплату, этап кандидата и т.п. — вызови appstroy_command. Инструмент только подготавливает безопасное действие; окончательное изменение выполняется после отдельного подтверждения в интерфейсе AppСтрой.",
  "Для общих вопросов, объяснений, идей, текстов и обсуждения можешь отвечать напрямую без инструмента.",
  "Не рассказывай пользователю про внутренние роутеры, edge-функции и техническую реализацию, если он сам об этом не спрашивает.",
  "Отвечай по-русски, естественно и по делу.",
].join("\n");

const APP_TOOL = {
  type: "function",
  name: "appstroy_command",
  description:
    "Прочитать актуальные данные AppСтрой или подготовить действие в AppСтрой от имени текущего пользователя. Используй для любых запросов, зависящих от живых данных компании, и для любых изменений данных.",
  parameters: {
    type: "object",
    properties: {
      prompt: {
        type: "string",
        description:
          "Полная рабочая команда для AppСтрой. Сохрани имена, даты, суммы, объект и смысл запроса пользователя.",
      },
    },
    required: ["prompt"],
    additionalProperties: false,
  },
  strict: true,
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

function outputText(payload: any): string {
  if (typeof payload?.output_text === "string") return payload.output_text.trim();
  const output = Array.isArray(payload?.output) ? payload.output : [];
  const parts: string[] = [];
  for (const item of output) {
    if (item?.type !== "message" || !Array.isArray(item?.content)) continue;
    for (const part of item.content) {
      if (part?.type === "output_text" && typeof part?.text === "string") {
        const text = part.text.trim();
        if (text) parts.push(text);
      }
    }
  }
  return parts.join("\n\n").trim();
}

function conversationContext(recent: ChatRow[], source: ChatRow): JsonMap {
  const prior = recent.filter((item) => item.id !== source.id);
  const lastAssistant = [...prior]
    .reverse()
    .find((item) => item.kind === "assistant");
  const payload = mapValue(lastAssistant?.ai_payload);
  const conversation = mapValue(payload.conversation);
  const previousUser = [...prior].reverse().find((item) => item.kind === "user");

  const result: JsonMap = {};
  const topic = clean(conversation.topic, 100);
  const queryMode = clean(conversation.query_mode, 60);
  const objectName = clean(conversation.object_name, 180);
  const date = clean(conversation.date, 32);
  const previousPrompt = clean(conversation.prompt, 1200) ||
    clean(previousUser?.body, 1200);
  if (topic) result.topic = topic;
  if (queryMode) result.query_mode = queryMode;
  if (objectName) result.object_name = objectName;
  if (date) result.date = date;
  if (previousPrompt) result.prompt = previousPrompt;
  return result;
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
}): Promise<{ data: JsonMap; status: number }> {
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
      input_mode: "chatgpt",
    }),
  });
  return {
    data: await response.json().catch(() => ({})) as JsonMap,
    status: response.status,
  };
}

async function openAiResponse({
  apiKey,
  model,
  input,
}: {
  apiKey: string;
  model: string;
  input: unknown[];
}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25_000);
  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        input,
        tools: [APP_TOOL],
        tool_choice: "auto",
        store: false,
      }),
      signal: controller.signal,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(
        payload?.error?.message || `OpenAI API error ${response.status}`,
      );
    }
    return payload;
  } finally {
    clearTimeout(timer);
  }
}

function parseToolPrompt(call: any, fallback: string): string {
  try {
    const parsed = JSON.parse(String(call?.arguments ?? "{}"));
    return clean(parsed?.prompt, 4000) || fallback;
  } catch (_) {
    return fallback;
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
    const publishable = publishableKey();
    const secret = serviceKey();
    const authorization = request.headers.get("Authorization") ?? "";
    const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "";
    const model = Deno.env.get("OPENAI_MODEL")?.trim() || "gpt-5-mini";
    if (!supabaseUrl || !publishable || !secret || !authorization || !apiKey) {
      return json({ error: "ChatGPT для AppСтрой не настроен" }, 500);
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
      return json({ error: "Не указано сообщение для ChatGPT" }, 400);
    }

    const [{ data: canUseAi, error: aiPermissionError }, { data: canViewChat, error: chatPermissionError }] =
      await Promise.all([
        userClient.rpc("current_user_has_permission", {
          p_permission_code: "ai.use",
        }),
        userClient.rpc("current_user_has_permission", {
          p_permission_code: "company_chat.view",
        }),
      ]);
    if (aiPermissionError) throw aiPermissionError;
    if (chatPermissionError) throw chatPermissionError;
    if (canUseAi !== true) return json({ error: "Для этой роли ChatGPT отключён" }, 403);
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
      return json({ error: "ChatGPT может отвечать только на твой запрос" }, 403);
    }
    if (source.channel_kind !== "assistant" || source.peer_user_id !== user.id) {
      return json({ error: "Открой ChatGPT в разделе чата" }, 400);
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
    if (existing?.id) {
      return json({ ok: true, message_id: existing.id, duplicate: true });
    }

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
      return json({ error: "Подожди несколько секунд перед следующим сообщением" }, 429);
    }

    const { data: recentData, error: recentError } = await admin
      .from("company_chat_messages")
      .select("id,company_id,sender_user_id,sender_name,kind,channel_kind,peer_user_id,thread_key,body,created_at,deleted_at,ai_payload")
      .eq("company_id", companyId)
      .eq("thread_key", source.thread_key)
      .gte("created_at", CHATGPT_CUTOVER)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(20);
    if (recentError) throw recentError;
    const recent = ((recentData ?? []) as ChatRow[]).reverse();
    const context = conversationContext(recent, source);

    const history = recent
      .filter((item) => item.id !== source.id && item.body.trim())
      .slice(-12)
      .map((item) => ({
        role: item.kind === "assistant" ? "assistant" : "user",
        content: item.body.slice(0, 1800),
      }));

    const initialInput: unknown[] = [
      {
        role: "developer",
        content: [
          APP_KNOWLEDGE,
          `Текущая роль в AppСтрой: ${role || "не указана"}.`,
          objectName
            ? `Выбранный объект: ${objectName}.`
            : "Конкретный объект сейчас явно не выбран.",
        ].join("\n\n"),
      },
      ...history,
      { role: "user", content: source.body.slice(0, 4000) },
    ];

    let responsePayload = await openAiResponse({ apiKey, model, input: initialInput });
    let latestAppResult: JsonMap = {};
    let latestAppStatus = 0;

    const calls = (Array.isArray(responsePayload?.output) ? responsePayload.output : [])
      .filter((item: any) => item?.type === "function_call" && item?.name === "appstroy_command")
      .slice(0, 3);

    if (calls.length > 0) {
      const outputs: unknown[] = [];
      for (const call of calls) {
        const toolPrompt = parseToolPrompt(call, source.body);
        const appResult = await invokeAppStroy({
          supabaseUrl,
          publishable,
          authorization,
          companyId,
          objectName,
          prompt: toolPrompt,
          context,
        });
        latestAppResult = appResult.data;
        latestAppStatus = appResult.status;
        outputs.push({
          type: "function_call_output",
          call_id: String(call.call_id ?? ""),
          output: JSON.stringify({
            status: appResult.status,
            result: appResult.data,
          }),
        });
      }

      const followInput: unknown[] = [
        ...initialInput,
        ...(Array.isArray(responsePayload?.output) ? responsePayload.output : []),
        ...outputs,
      ];
      responsePayload = await openAiResponse({
        apiKey,
        model,
        input: followInput,
      });
    }

    let answer = outputText(responsePayload);
    if (!answer && Object.keys(latestAppResult).length > 0) {
      answer = clean(latestAppResult.summary, 6000) ||
        clean(latestAppResult.error, 6000) ||
        "AppСтрой вернул результат без текстового описания.";
    }
    if (!answer) answer = "Не получилось сформировать ответ. Попробуй написать иначе.";

    const storedPayload: JsonMap = {
      title: "ChatGPT",
      summary: answer,
      ai_used: true,
      assistant_mode: "chatgpt_app_tools",
      model,
      app_tool_used: calls.length > 0,
      app_tool_status: latestAppStatus,
      unified_assistant: false,
      input_mode: "chatgpt",
    };
    const action = mapValue(latestAppResult.action);
    if (Object.keys(action).length > 0) storedPayload.action = action;
    const appConversation = mapValue(latestAppResult.conversation);
    if (Object.keys(appConversation).length > 0) {
      storedPayload.conversation = appConversation;
    }
    const semanticRoute = mapValue(latestAppResult.semantic_route);
    if (Object.keys(semanticRoute).length > 0) {
      storedPayload.semantic_route = semanticRoute;
    }

    const { data: inserted, error: insertError } = await admin
      .from("company_chat_messages")
      .insert({
        company_id: companyId,
        sender_user_id: null,
        sender_name: "ChatGPT",
        sender_role: "ai",
        kind: "assistant",
        channel_kind: "assistant",
        peer_user_id: user.id,
        thread_key: source.thread_key,
        body: answer.slice(0, 6000),
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

    return json({
      ok: true,
      message_id: inserted.id,
      assistant: "chatgpt",
      model,
      app_tool_used: calls.length > 0,
    });
  } catch (error) {
    console.error("company-chat-gpt failed", error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
