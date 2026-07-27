import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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

function normalizePhone(value: unknown) {
  const digits = String(value ?? "").replace(/\D/g, "");
  if (digits.length === 11 && (digits.startsWith("7") || digits.startsWith("8"))) {
    return `+7${digits.slice(1)}`;
  }
  if (digits.length === 10) return `+7${digits}`;
  return "";
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
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Вход сотрудников не настроен" }, 500);
    }

    const input = await request.json();
    const phone = normalizePhone(input.phone);
    if (!phone) {
      return json({ ok: false, error: "Некорректный номер телефона" });
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: links, error: linksError } = await adminClient
      .from("employee_account_links")
      .select("company_id, person_id, user_id")
      .eq("phone_e164", phone)
      .eq("is_active", true)
      .limit(20);
    if (linksError) throw linksError;

    const companyIds = Array.from(
      new Set((links ?? []).map((row) => String(row.company_id))),
    );
    const userIds = Array.from(
      new Set((links ?? []).map((row) => String(row.user_id))),
    );
    if (companyIds.length === 0 || userIds.length === 0) {
      return json({
        ok: false,
        error: "Этот номер не подключён к кабинету сотрудника",
      });
    }

    const [{ data: company }, { data: profile }, { data: maxLinks }] =
      await Promise.all([
        adminClient
          .from("companies")
          .select("id")
          .in("id", companyIds)
          .eq("status", "active")
          .limit(1)
          .maybeSingle(),
        adminClient
          .from("user_profiles")
          .select("id")
          .in("id", userIds)
          .eq("role", "employee")
          .eq("is_active", true)
          .limit(1)
          .maybeSingle(),
        adminClient
          .from("employee_max_links")
          .select("company_id, person_id, user_id, max_user_id")
          .eq("phone_e164", phone)
          .eq("is_active", true)
          .limit(20),
      ]);

    if (!company || !profile) {
      return json({
        ok: false,
        error: "Доступ сотрудника отключён. Обратитесь к руководителю",
      });
    }

    const accountKeys = new Set(
      (links ?? []).map(
        (row) => `${row.company_id}:${row.person_id}:${row.user_id}`,
      ),
    );
    const validMaxUsers = new Set(
      (maxLinks ?? [])
        .filter((row) =>
          accountKeys.has(`${row.company_id}:${row.person_id}:${row.user_id}`)
        )
        .map((row) => String(row.max_user_id)),
    );
    if (validMaxUsers.size !== 1) {
      return json({
        ok: false,
        error:
          "MAX не подключён к кабинету сотрудника. Получите ссылку подключения у руководителя",
      });
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error: otpError } = await authClient.auth.signInWithOtp({
      phone,
      options: { shouldCreateUser: false },
    });
    if (otpError) throw otpError;

    return json({ ok: true, channel: "max" });
  } catch (error) {
    console.error("Employee MAX OTP request failed", {
      name: error instanceof Error ? error.name : "UnknownError",
    });
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message || "Не удалось отправить код в MAX" }, 500);
  }
});
