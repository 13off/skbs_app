import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const publishedWebAppUrl = "https://13off.github.io/appstroy-web/";

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

function publicInvitationUrl(value: unknown) {
  const source = new URL(String(value ?? ""));
  const companyId = source.searchParams.get("companyInvite")?.trim() ?? "";
  const tokenHash = source.searchParams.get("inviteTokenHash")?.trim() ?? "";
  const inviteType = source.searchParams.get("inviteType")?.trim() ?? "";
  if (!companyId || !tokenHash || !inviteType) {
    throw new Error("Сервис вернул неполную ссылку приглашения");
  }

  const target = new URL("invite.html", publishedWebAppUrl);
  target.searchParams.set("companyInvite", companyId);
  target.searchParams.set("inviteTokenHash", tokenHash);
  target.searchParams.set("inviteType", inviteType);
  return target.toString();
}

function publicRedirectUrl(value: unknown) {
  const source = new URL(String(value ?? ""));
  const companyId = source.searchParams.get("companyInvite")?.trim() ?? "";
  const target = new URL(publishedWebAppUrl);
  if (companyId) target.searchParams.set("companyInvite", companyId);
  return target.toString();
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

    // Ядро остаётся единственным местом генерации одноразового токена и
    // проверки ролей. Публичный адаптер меняет только web-маршрут, чтобы
    // приглашение не зависело от /app на API-прокси.
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

    if (coreResponse.ok && data && typeof data === "object") {
      const result = data as Record<string, unknown>;
      result.invite_url = publicInvitationUrl(result.invite_url);
      result.redirect_to = publicRedirectUrl(result.redirect_to);
    }

    return json(data, coreResponse.status);
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
