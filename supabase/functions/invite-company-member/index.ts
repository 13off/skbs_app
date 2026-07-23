import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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
    if (!supabaseUrl || !anonKey || !authorization) {
      return json({ error: "Сервис приглашений не настроен" }, 500);
    }

    // Ядро приглашений является единственным источником публичного web-адреса.
    // Адаптер сохраняет стабильное имя функции и не переписывает ссылку.
    const coreResponse = await fetch(
      `${supabaseUrl}/functions/v1/invite-company-member-core`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "apikey": anonKey,
          "Authorization": authorization,
        },
        body: await request.text(),
      },
    );
    const data = await coreResponse.json().catch(() => ({}));
    return json(data, coreResponse.status);
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
