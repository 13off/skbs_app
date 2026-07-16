import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

    // invite-company-member-core выполняет generateLink для type: "invite",
    // "recovery" и "magiclink", затем возвращает invite_url: actionLink.
    // Этот адаптер не дублирует Auth-логику и меняет только публичный маршрут.
    const body = await request.text();
    const coreResponse = await fetch(
      `${supabaseUrl}/functions/v1/invite-company-member-core`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "apikey": anonKey,
          "Authorization": authorization,
        },
        body,
      },
    );
    const data = await coreResponse.json().catch(() => ({}));
    if (!coreResponse.ok) {
      return json(data, coreResponse.status);
    }

    const oldInviteUrl = String(data.invite_url ?? "").trim();
    if (!oldInviteUrl) {
      return json({ error: "Сервис не вернул ссылку приглашения" }, 502);
    }

    const oldUrl = new URL(oldInviteUrl);
    const companyId = oldUrl.searchParams.get("companyInvite") ?? "";
    const tokenHash = oldUrl.searchParams.get("inviteTokenHash") ?? "";
    const inviteType = oldUrl.searchParams.get("inviteType") ?? "invite";
    if (!companyId || !tokenHash) {
      return json({ error: "Сервис вернул неполную ссылку приглашения" }, 502);
    }

    const landingUrl = new URL("invite.html", publishedWebAppUrl);
    landingUrl.searchParams.set("companyInvite", companyId);
    landingUrl.searchParams.set("inviteTokenHash", tokenHash);
    landingUrl.searchParams.set("inviteType", inviteType);

    const redirectUrl = new URL(publishedWebAppUrl);
    redirectUrl.searchParams.set("companyInvite", companyId);

    return json({
      ...data,
      invite_url: landingUrl.toString(),
      redirect_to: redirectUrl.toString(),
    });
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
