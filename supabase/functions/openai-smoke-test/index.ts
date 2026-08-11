import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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

function extractOutputText(payload: any): string {
  if (typeof payload?.output_text === "string") return payload.output_text;
  const output = Array.isArray(payload?.output) ? payload.output : [];
  for (const item of output) {
    if (item?.type !== "message" || !Array.isArray(item?.content)) continue;
    for (const part of item.content) {
      if (part?.type === "output_text" && typeof part?.text === "string") {
        return part.text;
      }
    }
  }
  return "";
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Метод не поддерживается" }, 405);
  }

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

  const input = await request.json().catch(() => ({}));
  const prompt = String(
    input?.prompt ?? "Привет! Подтверди, что OpenAI API подключён к AppСтрой.",
  ).trim().slice(0, 4000);

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
            content: "Ты тестовый ИИ-модуль AppСтрой. Отвечай кратко по-русски.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
      }),
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
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});
