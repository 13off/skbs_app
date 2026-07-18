import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function clean(value: unknown, max = 8000) {
  return String(value ?? "").trim().slice(0, max);
}

function outputText(value: any) {
  if (typeof value?.output_text === "string") return value.output_text.trim();
  const parts: string[] = [];
  for (const item of value?.output ?? []) {
    for (const content of item?.content ?? []) {
      if (typeof content?.text === "string") parts.push(content.text);
    }
  }
  return parts.join("\n").trim();
}

async function makeAiComment(payload: unknown) {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) return "";
  try {
    const result = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") || "gpt-5-mini",
        instructions:
          "Ты ИИ-диспетчер строительной компании. Данные относятся только к одному указанному объекту. В первой строке обязательно назови объект. Не смешивай данные других объектов и не выдумывай факты. Затем дай итог дня, риски и 2-4 конкретных действия. Не используй таблицы. До 1200 символов.",
        input: JSON.stringify(payload),
        max_output_tokens: 700,
      }),
    });
    if (!result.ok) return "";
    return outputText(await result.json());
  } catch (_) {
    return "";
  }
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return reply({ error: "Метод не поддерживается" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply({ error: "Сервис не настроен" }, 500);

  const client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let runId = "";
  let token = "";
  try {
    finalInput: {
      const input = await request.json().catch(() => ({}));
      runId = clean(input.run_id, 80);
      token = clean(input.dispatch_token, 80);
    }
    if (!runId || !token) return reply({ error: "Не указан запуск" }, 400);

    const { data, error } = await client.rpc(
      "prepare_dispatcher_object_summary",
      { p_run_id: runId, p_dispatch_token: token },
    );
    if (error) throw error;
    if (data?.already_sent === true) {
      return reply({ ok: true, already_sent: true, run_id: runId });
    }

    const fallback = clean(data?.fallback);
    const generated = data?.ai_commentary === true
      ? await makeAiComment(data?.payload)
      : "";
    const body = generated || fallback;

    const { data: finalized, error: finalizeError } = await client.rpc(
      "finalize_dispatcher_object_summary",
      {
        p_run_id: runId,
        p_dispatch_token: token,
        p_title: clean(data?.title, 240),
        p_body: body,
        p_payload: data?.payload ?? {},
        p_ai_used: generated.length > 0,
        p_critical_count: Number(data?.critical_count ?? 0),
      },
    );
    if (finalizeError) throw finalizeError;

    return reply({
      ok: true,
      finalized,
      run_id: runId,
      object_id: data?.object_id,
      object_name: data?.object_name,
      ai_used: generated.length > 0,
      critical_count: Number(data?.critical_count ?? 0),
    });
  } catch (error) {
    console.error(error);
    if (runId && token) {
      await client.rpc("fail_dispatcher_object_summary", {
        p_run_id: runId,
        p_dispatch_token: token,
        p_error_text: error instanceof Error ? error.message : String(error),
      });
    }
    return reply(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
