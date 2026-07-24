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

function normalize(value: string): string {
  return value.toLowerCase().replaceAll("ё", "е");
}

function functionNameFor(prompt: string): string {
  const normalized = normalize(prompt);
  const operationalInsight =
    /(кто|кого|сотрудник).*(не выш|не явил|отсутств|нет на работ)/.test(normalized) ||
    /(кому|у кого|кто).*(не выплат|не доплат|должн|долг|остаток|задолж)/.test(normalized) ||
    /(документ|договор|удостоверен|медосмотр|патент).*(заканч|истека|просроч|срок)/.test(normalized) ||
    /(сводк|отчет|итог).*(недел|7 дн)/.test(normalized);
  if (operationalInsight) return "ai-operational-insights";

  const taskCommand = /(созда|добав|постав|назнач|сдел).*(задач|работ|армирован|бетонир|монтаж|демонтаж)/.test(normalized);
  if (taskCommand) return "ai-action-draft";

  const documentCommand = /(подготов|состав|напиш|созда|сдел|сформир).*(документ|заявлен|договор|соглас|служебн|записк|письм)/.test(normalized);
  if (documentCommand) return "ai-document-draft";

  const operationalCommand = /(напомн|напоминан|исправ|измен|поправ|постав|отмет|выплат|аванс|зарплат|чек|табел|смен)/.test(normalized);
  if (operationalCommand) return "ai-operational-draft";

  return "ai-search";
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
  return parts.join("\n\n").slice(0, 5000) || "Помощник не вернул текстовый ответ.";
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Метод не поддерживается" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const secret = serviceKey();
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !secret || !authorization) {
      return json({ error: "Сервис ИИ чата не настроен" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
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

    const { data: sourceData, error: sourceError } = await admin
      .from("company_chat_messages")
      .select("id,company_id,sender_user_id,sender_name,kind,channel_kind,peer_user_id,thread_key,body,created_at,deleted_at")
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
      .select("id,company_id,sender_user_id,sender_name,kind,channel_kind,peer_user_id,thread_key,body,created_at,deleted_at")
      .eq("company_id", companyId)
      .eq("thread_key", source.thread_key)
      .is("deleted_at", null)
      .order("created_at", { ascending: false })
      .limit(16);
    if (recentError) throw recentError;
    const recent = ((recentData ?? []) as ChatRow[]).reverse();
    const context = recent
      .filter((item) => item.body.trim())
      .map((item) => `${item.kind === "assistant" ? "ИИ" : item.sender_name}: ${item.body.slice(0, 600)}`)
      .join("\n")
      .slice(-7000);

    const prompt = [
      "Ты отвечаешь в личном диалоге ИИ-помощника AppСтрой.",
      "Учитывай предыдущие сообщения этого пользователя, но факты о сотрудниках, объектах, задачах, табеле, выплатах и документах проверяй через доступные данные приложения.",
      "Не утверждай, что изменение выполнено: любые изменения должны остаться черновиком и требовать подтверждения пользователя.",
      context ? `Предыдущие сообщения диалога:\n${context}` : "",
      `Запрос пользователя:\n${source.body}`,
    ].filter(Boolean).join("\n\n");

    const targetFunction = functionNameFor(source.body);
    const aiResponse = await fetch(`${supabaseUrl}/functions/v1/${targetFunction}`, {
      method: "POST",
      headers: {
        "Authorization": authorization,
        "apikey": anonKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        mode: "chat",
        company_id: companyId,
        object_name: objectName || null,
        date: new Date().toISOString().slice(0, 10),
        prompt,
      }),
    });
    const aiData = await aiResponse.json().catch(() => ({})) as JsonMap;
    const aiError = clean(aiData.error, 1000);
    if (!aiResponse.ok || aiError) {
      return json({ error: aiError || "ИИ-помощник временно недоступен" }, aiResponse.status || 500);
    }

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
        body: resultText(aiData),
        reply_to_id: sourceMessageId,
        mentioned_user_ids: [user.id],
        ai_payload: aiData,
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

    return json({ ok: true, message_id: inserted.id, function: targetFunction });
  } catch (error) {
    console.error("company-chat-ai failed", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
