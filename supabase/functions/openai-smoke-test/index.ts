import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const maxRequestBytes = 8 * 1024;

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

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object"
    ? value as Record<string, unknown>
    : {};
}

function extractOutputText(payload: unknown): string {
  const root = asRecord(payload);
  if (typeof root.output_text === "string") return root.output_text;
  const output = Array.isArray(root.output) ? root.output : [];
  for (const itemValue of output) {
    const item = asRecord(itemValue);
    if (item.type !== "message" || !Array.isArray(item.content)) continue;
    for (const partValue of item.content) {
      const part = asRecord(partValue);
      if (part.type === "output_text" && typeof part.text === "string") {
        return part.text;
      }
    }
  }
  return "";
}

async function authorize(request: Request): Promise<Response | null> {
  const authorization = request.headers.get("authorization")?.trim() ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!authorization.startsWith("Bearer ") || !supabaseUrl || !anonKey) {
    return json({ error: "Требуется авторизация" }, 401);
  }

  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "Недействительная сессия" }, 401);
  }
  const { data: profile, error: profileError } = await client
    .from("user_profiles")
    .select("is_active,active_company_id")
    .eq("id", userData.user.id)
    .maybeSingle();
  const companyId = String(profile?.active_company_id ?? "").trim();
  if (profileError || !profile || profile.is_active !== true || !companyId) {
    return json({ error: "Профиль недоступен" }, 403);
  }
  const { data: membership, error: membershipError } = await client
    .from("company_memberships")
    .select("role,is_active")
    .eq("company_id", companyId)
    .eq("user_id", userData.user.id)
    .maybeSingle();
  if (membershipError || !membership || membership.is_active !== true) {
    return json({ error: "Членство в компании недоступно" }, 403);
  }
  if (!["owner", "admin", "developer"].includes(String(membership.role))) {
    return json({ error: "Недостаточно прав для диагностики ИИ" }, 403);
  }
  return null;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Метод не поддерживается" }, 405);
  }

  const authError = await authorize(request);
  if (authError) return authError;

  const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "";
  const model = Deno.env.get("OPENAI_MODEL")?.trim() || "gpt-5-mini";
  if (!apiKey) {
    return json({
      ok: false,
      configured: false,
      error: "OPENAI_API_KEY не задан в Supabase Edge Function Secrets",
      model,
    }, 503);
  }

  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(declaredLength) && declaredLength > maxRequestBytes) {
    return json({ error: "Запрос слишком большой" }, 413);
  }
  const rawInput = await request.text();
  if (rawInput.length > maxRequestBytes) {
    return json({ error: "Запрос слишком большой" }, 413);
  }
  let input: Record<string, unknown> = {};
  if (rawInput.trim()) {
    try {
      input = asRecord(JSON.parse(rawInput));
    } catch (_) {
      return json({ error: "Некорректный JSON" }, 400);
    }
  }
  const prompt = String(
    input.prompt ?? "Привет! Подтверди, что OpenAI API подключён к AppСтрой.",
  ).trim().slice(0, 1000);

  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        input: [
          {
            role: "system",
            content:
              "Ты тестовый ИИ-модуль AppСтрой. Отвечай кратко по-русски.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        max_output_tokens: 200,
      }),
      signal: AbortSignal.timeout(30_000),
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      console.error("OpenAI API error", response.status, payload);
      return json({
        ok: false,
        configured: true,
        model,
        upstream_status: response.status,
        error: payload?.error?.message || "OpenAI API вернул ошибку",
      }, 502);
    }

    return json({
      ok: true,
      configured: true,
      model,
      answer: extractOutputText(payload),
      response_id: payload?.id ?? null,
      usage: payload?.usage ?? null,
    });
  } catch (error) {
    console.error("OpenAI request failed", error);
    return json({
      ok: false,
      configured: true,
      model,
      error: "Не удалось выполнить диагностический запрос к OpenAI",
    }, 500);
  }
});
