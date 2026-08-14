import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "content-type, x-appstroy-max-secret, x-client-info, apikey",
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
  if (digits.length === 10) return `+7${digits}`;
  if (digits.length === 11 && (digits.startsWith("7") || digits.startsWith("8"))) {
    return `+7${digits.slice(1)}`;
  }
  if (digits.length >= 8 && digits.length <= 15) return `+${digits}`;
  return "";
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function secureEqual(left: string, right: string) {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index += 1) {
    difference |= a[index] ^ b[index];
  }
  return difference === 0;
}

function parseMaxId(value: unknown) {
  const text = String(value ?? "").trim();
  return /^\d{1,19}$/.test(text) ? text : "";
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
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Мост MAX не настроен" }, 500);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: storedSecret, error: secretError } = await adminClient.rpc(
      "get_recruitment_secret",
      { p_name: "max_recruitment_bridge_secret" },
    );
    if (secretError) throw secretError;
    const providedSecret =
      request.headers.get("x-appstroy-max-secret")?.trim() ?? "";
    const expectedSecret = String(storedSecret ?? "").trim();
    if (
      !providedSecret ||
      !expectedSecret ||
      !secureEqual(providedSecret, expectedSecret)
    ) {
      return json({ error: "Доступ запрещён" }, 401);
    }

    const input = await request.json();
    const action = String(input.action ?? "link_verified_phone").trim();
    const maxUserId = parseMaxId(input.max_user_id);
    const maxChatId = parseMaxId(input.max_chat_id);
    const maxUsername = String(input.max_username ?? "").trim().slice(0, 120);
    const phone = normalizePhone(input.phone);
    const contactVerified = input.contact_verified === true;
    if (!maxUserId || !phone || !contactVerified) {
      return json(
        { error: "Нужен подтверждённый контакт владельца MAX-аккаунта" },
        400,
      );
    }

    let claimedTokenHash = "";
    let loginAttemptId = "";
    let accountLink: {
      company_id: string;
      person_id: string;
      user_id: string;
      phone_e164: string;
    } | null = null;

    if (action === "claim_token") {
      const connectToken = String(input.connect_token ?? "").trim();
      if (connectToken.length < 24 || connectToken.length > 128) {
        return json({ error: "Код подключения некорректен" }, 400);
      }
      claimedTokenHash = await sha256(connectToken);
      const { data: pendingToken, error: tokenError } = await adminClient
        .from("employee_max_link_tokens")
        .select(
          "company_id, person_id, user_id, phone_e164, expires_at, used_at, login_attempt_id",
        )
        .eq("token_hash", claimedTokenHash)
        .maybeSingle();
      if (tokenError) throw tokenError;
      if (
        !pendingToken ||
        pendingToken.used_at != null ||
        new Date(pendingToken.expires_at).getTime() <= Date.now()
      ) {
        return json({ error: "Код подключения истёк или уже использован" }, 410);
      }
      if (normalizePhone(pendingToken.phone_e164) !== phone) {
        return json(
          { error: "Номер MAX не совпадает с карточкой сотрудника" },
          409,
        );
      }
      loginAttemptId = String(pendingToken.login_attempt_id ?? "").trim();
      accountLink = {
        company_id: String(pendingToken.company_id),
        person_id: String(pendingToken.person_id),
        user_id: String(pendingToken.user_id),
        phone_e164: phone,
      };
    } else if (action === "link_verified_phone") {
      const { data: links, error: linksError } = await adminClient
        .from("employee_account_links")
        .select("company_id, person_id, user_id, phone_e164")
        .eq("phone_e164", phone)
        .eq("is_active", true)
        .limit(10);
      if (linksError) throw linksError;
      const uniqueLinks = new Map(
        (links ?? []).map((row) => [
          `${row.company_id}:${row.person_id}:${row.user_id}`,
          row,
        ]),
      );
      if (uniqueLinks.size === 0) {
        return json(
          { error: "Этот номер не подключён к кабинету сотрудника" },
          404,
        );
      }
      if (uniqueLinks.size > 1) {
        return json(
          { error: "Для этого номера нужен персональный код подключения" },
          409,
        );
      }
      const row = Array.from(uniqueLinks.values())[0];
      accountLink = {
        company_id: String(row.company_id),
        person_id: String(row.person_id),
        user_id: String(row.user_id),
        phone_e164: phone,
      };
    } else {
      return json({ error: "Неизвестное действие" }, 400);
    }

    const [{ data: company }, { data: profile }] = await Promise.all([
      adminClient
        .from("companies")
        .select("id")
        .eq("id", accountLink.company_id)
        .eq("status", "active")
        .maybeSingle(),
      adminClient
        .from("user_profiles")
        .select("id")
        .eq("id", accountLink.user_id)
        .eq("role", "employee")
        .eq("is_active", true)
        .maybeSingle(),
    ]);
    if (!company || !profile) {
      return json({ error: "Доступ сотрудника отключён" }, 403);
    }

    const now = new Date().toISOString();
    const { error: linkError } = await adminClient
      .from("employee_max_links")
      .upsert(
        {
          company_id: accountLink.company_id,
          person_id: accountLink.person_id,
          user_id: accountLink.user_id,
          phone_e164: accountLink.phone_e164,
          max_user_id: maxUserId,
          max_chat_id: maxChatId || null,
          max_username: maxUsername,
          source: "bot_contact",
          is_active: true,
          linked_at: now,
          updated_at: now,
        },
        { onConflict: "company_id,person_id" },
      );
    if (linkError) throw linkError;

    if (claimedTokenHash) {
      const { error: useTokenError } = await adminClient
        .from("employee_max_link_tokens")
        .update({
          used_at: now,
          claimed_max_user_id: maxUserId,
        })
        .eq("token_hash", claimedTokenHash)
        .is("used_at", null);
      if (useTokenError) throw useTokenError;
    }

    let loginStarted = false;
    if (loginAttemptId && anonKey) {
      const { data: attempt, error: attemptError } = await adminClient
        .from("employee_max_login_attempts")
        .select("id, expires_at, state")
        .eq("id", loginAttemptId)
        .eq("company_id", accountLink.company_id)
        .eq("person_id", accountLink.person_id)
        .eq("user_id", accountLink.user_id)
        .eq("phone_e164", accountLink.phone_e164)
        .maybeSingle();
      if (attemptError) throw attemptError;
      if (
        attempt &&
        attempt.state === "linking" &&
        new Date(attempt.expires_at).getTime() > Date.now()
      ) {
        const { data: claimedAttempt, error: claimError } = await adminClient
          .from("employee_max_login_attempts")
          .update({
            state: "pending",
            max_user_id: maxUserId,
            updated_at: now,
          })
          .eq("id", loginAttemptId)
          .eq("state", "linking")
          .select("id")
          .maybeSingle();
        if (claimError) throw claimError;
        if (claimedAttempt) {
          const authClient = createClient(supabaseUrl, anonKey, {
            auth: { persistSession: false, autoRefreshToken: false },
          });
          const { error: otpError } = await authClient.auth.signInWithOtp({
            phone: accountLink.phone_e164,
            options: { shouldCreateUser: false },
          });
          if (otpError) throw otpError;
          loginStarted = true;
        }
      }
    }

    return json({
      ok: true,
      linked: true,
      login_started: loginStarted,
      message: loginStarted
        ? "MAX подключён. Сейчас придёт кнопка подтверждения входа в AppСтрой."
        : "MAX подключён. Теперь вход в AppСтрой можно подтверждать одной кнопкой.",
      app_url:
        Deno.env.get("APP_PUBLIC_URL")?.trim() ||
        "https://13off.github.io/appstroy-web/",
    });
  } catch (error) {
    console.error("MAX employee link bridge failed", {
      name: error instanceof Error ? error.name : "UnknownError",
    });
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message || "Не удалось подключить MAX" }, 500);
  }
});
