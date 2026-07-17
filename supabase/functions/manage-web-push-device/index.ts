import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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

function clean(value: unknown) {
  return String(value ?? "").trim();
}

function serviceKey(): string {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, string>;
      return parsed.default ?? Object.values(parsed)[0] ?? "";
    } catch (_) {
      // Fall back to the legacy service-role variable.
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
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
    const serviceRoleKey = serviceKey();
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
      return json({ error: "Web Push сервис Supabase не настроен" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const input = await request.json().catch(() => ({}));
    const action = clean(input.action);
    const deviceId = clean(input.device_id);
    if (!deviceId) return json({ error: "device_id обязателен" }, 400);
    if (!["register", "set_enabled", "unregister"].includes(action)) {
      return json({ error: "Неизвестное действие" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (action === "unregister") {
      const { error } = await admin
        .from("web_push_subscriptions")
        .delete()
        .eq("user_id", userData.user.id)
        .eq("device_id", deviceId);
      if (error) throw error;
      return json({ ok: true, action, removed: true });
    }

    const { data: profile, error: profileError } = await admin
      .from("user_profiles")
      .select("active_company_id,is_active")
      .eq("id", userData.user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    const companyId = clean(profile?.active_company_id);
    if (!profile || profile.is_active !== true || !companyId) {
      return json({ error: "Не выбрана активная компания" }, 403);
    }

    const { data: membership, error: membershipError } = await admin
      .from("company_memberships")
      .select("user_id")
      .eq("company_id", companyId)
      .eq("user_id", userData.user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return json({ error: "Нет доступа к активной компании" }, 403);

    if (action === "set_enabled") {
      const enabled = input.enabled === true;
      const { error } = await admin
        .from("web_push_subscriptions")
        .update({
          enabled,
          company_id: companyId,
          last_seen_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", userData.user.id)
        .eq("device_id", deviceId);
      if (error) throw error;
      return json({ ok: true, action, enabled });
    }

    const endpoint = clean(input.endpoint);
    const p256dh = clean(input.p256dh);
    const auth = clean(input.auth);
    const userAgent = clean(input.user_agent).slice(0, 1000);
    if (!endpoint.startsWith("https://")) {
      return json({ error: "Некорректный endpoint Web Push" }, 400);
    }
    if (!p256dh || !auth) {
      return json({ error: "Ключи подписки Web Push обязательны" }, 400);
    }

    const expirationRaw = input.expiration_time;
    const expirationTime = typeof expirationRaw === "number" &&
        Number.isFinite(expirationRaw)
      ? Math.trunc(expirationRaw)
      : null;

    const { error: endpointDeleteError } = await admin
      .from("web_push_subscriptions")
      .delete()
      .eq("endpoint", endpoint);
    if (endpointDeleteError) throw endpointDeleteError;

    const { error: deviceDeleteError } = await admin
      .from("web_push_subscriptions")
      .delete()
      .eq("user_id", userData.user.id)
      .eq("device_id", deviceId);
    if (deviceDeleteError) throw deviceDeleteError;

    const now = new Date().toISOString();
    const { data: inserted, error: insertError } = await admin
      .from("web_push_subscriptions")
      .insert({
        user_id: userData.user.id,
        company_id: companyId,
        device_id: deviceId,
        endpoint,
        p256dh,
        auth,
        expiration_time: expirationTime,
        user_agent: userAgent,
        enabled: input.enabled !== false,
        last_seen_at: now,
        updated_at: now,
      })
      .select("id")
      .single();
    if (insertError) throw insertError;

    return json({ ok: true, action, id: inserted.id });
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message || "Не удалось обновить Web Push подписку" }, 500);
  }
});
