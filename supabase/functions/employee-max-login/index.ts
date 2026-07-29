import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const activeAttemptStates = ["linking", "pending", "code_ready", "confirmed"];
const attemptLifetimeMs = 10 * 60 * 1000;
const sessionDeliveryLifetimeMs = 2 * 60 * 1000;

type EmployeeAccount = {
  company_id: string;
  person_id: string;
  user_id: string;
  phone_e164: string;
};

type LoginAttempt = EmployeeAccount & {
  id: string;
  max_user_id?: string | number | null;
  state: string;
  otp_ciphertext?: string | null;
  session_ciphertext?: string | null;
  expires_at: string;
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

function html(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
      "X-Frame-Options": "DENY",
    },
  });
}

function normalizePhone(value: unknown) {
  const digits = String(value ?? "").replace(/\D/g, "");
  if (digits.length === 10) return `+7${digits}`;
  if (digits.length === 11 && (digits.startsWith("7") || digits.startsWith("8"))) {
    return `+7${digits.slice(1)}`;
  }
  return "";
}

function randomToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return bytesToBase64Url(bytes);
}

function bytesToBase64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function base64UrlToBytes(value: string) {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function encryptionKey(serviceRoleKey: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`appstroy-max-login:${serviceRoleKey}`),
  );
  return crypto.subtle.importKey(
    "raw",
    digest,
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
}

async function encryptValue(value: string, serviceRoleKey: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    await encryptionKey(serviceRoleKey),
    new TextEncoder().encode(value),
  );
  return `${bytesToBase64Url(iv)}.${bytesToBase64Url(new Uint8Array(encrypted))}`;
}

async function decryptValue(value: string, serviceRoleKey: string) {
  const [ivText, encryptedText] = value.split(".");
  if (!ivText || !encryptedText) throw new Error("Данные входа повреждены");
  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: base64UrlToBytes(ivText) },
    await encryptionKey(serviceRoleKey),
    base64UrlToBytes(encryptedText),
  );
  return new TextDecoder().decode(decrypted);
}

async function readBotUsername(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
) {
  const fromEnvironment = Deno.env.get("MAX_BOT_USERNAME")?.trim() ?? "";
  if (fromEnvironment) return fromEnvironment.replace(/^@/, "");
  const { data, error } = await adminClient.rpc("get_recruitment_secret", {
    p_name: "max_bot_username",
  });
  if (error) throw error;
  return String(data ?? "").trim().replace(/^@/, "");
}

async function findEmployeeAccount(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  phone: string,
): Promise<EmployeeAccount> {
  const { data: rawLinks, error: linksError } = await adminClient
    .from("employee_account_links")
    .select("company_id, person_id, user_id, phone_e164")
    .eq("phone_e164", phone)
    .eq("is_active", true)
    .limit(20);
  if (linksError) throw linksError;

  const links = (rawLinks ?? []) as EmployeeAccount[];
  const userIds = Array.from(new Set(links.map((row) => String(row.user_id))));
  if (userIds.length === 0) {
    throw new Error("Этот номер не подключён к кабинету сотрудника");
  }
  if (userIds.length !== 1) {
    throw new Error("Для этого номера найдено несколько кабинетов. Обратитесь к руководителю");
  }

  const userId = userIds[0];
  const companyIds = Array.from(new Set(links.map((row) => String(row.company_id))));
  const [{ data: profile, error: profileError }, { data: companies, error: companiesError }] =
    await Promise.all([
      adminClient
        .from("user_profiles")
        .select("id")
        .eq("id", userId)
        .eq("role", "employee")
        .eq("is_active", true)
        .maybeSingle(),
      adminClient
        .from("companies")
        .select("id")
        .in("id", companyIds)
        .eq("status", "active"),
    ]);
  if (profileError) throw profileError;
  if (companiesError) throw companiesError;
  if (!profile) throw new Error("Доступ сотрудника отключён");

  const activeCompanies = new Set(
    (companies ?? []).map((row: { id: string }) => String(row.id)),
  );
  const account = links.find((row) => activeCompanies.has(String(row.company_id)));
  if (!account) throw new Error("Компания сотрудника временно недоступна");

  return {
    company_id: String(account.company_id),
    person_id: String(account.person_id),
    user_id: String(account.user_id),
    phone_e164: phone,
  };
}

async function readActiveMaxLink(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  account: EmployeeAccount,
) {
  const { data, error } = await adminClient
    .from("employee_max_links")
    .select("max_user_id, max_chat_id, max_username")
    .eq("company_id", account.company_id)
    .eq("person_id", account.person_id)
    .eq("user_id", account.user_id)
    .eq("phone_e164", account.phone_e164)
    .eq("is_active", true)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function requestOtp(
  supabaseUrl: string,
  anonKey: string,
  phone: string,
) {
  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await authClient.auth.signInWithOtp({
    phone,
    options: { shouldCreateUser: false },
  });
  if (error) throw error;
}

async function createAttempt({
  adminClient,
  account,
}: {
  // deno-lint-ignore no-explicit-any
  adminClient: any;
  account: EmployeeAccount;
}) {
  const now = Date.now();
  const recentThreshold = new Date(now - 60 * 1000).toISOString();
  const { count, error: countError } = await adminClient
    .from("employee_max_login_attempts")
    .select("id", { count: "exact", head: true })
    .eq("phone_e164", account.phone_e164)
    .gte("created_at", recentThreshold);
  if (countError) throw countError;
  if ((count ?? 0) >= 4) {
    throw new Error("Слишком много попыток. Подождите минуту и попробуйте снова");
  }

  await adminClient
    .from("employee_max_login_attempts")
    .update({ state: "expired", updated_at: new Date().toISOString() })
    .eq("phone_e164", account.phone_e164)
    .in("state", activeAttemptStates);

  const clientToken = randomToken();
  const expiresAt = new Date(now + attemptLifetimeMs).toISOString();
  const { data, error } = await adminClient
    .from("employee_max_login_attempts")
    .insert({
      client_token_hash: await sha256(clientToken),
      company_id: account.company_id,
      person_id: account.person_id,
      user_id: account.user_id,
      phone_e164: account.phone_e164,
      state: "pending",
      expires_at: expiresAt,
    })
    .select("id")
    .single();
  if (error) throw error;
  return { id: String(data.id), clientToken, expiresAt };
}

async function startLogin({
  adminClient,
  supabaseUrl,
  anonKey,
  phone,
}: {
  // deno-lint-ignore no-explicit-any
  adminClient: any;
  supabaseUrl: string;
  anonKey: string;
  phone: string;
}) {
  const account = await findEmployeeAccount(adminClient, phone);
  const attempt = await createAttempt({ adminClient, account });
  const maxLink = await readActiveMaxLink(adminClient, account);
  const botUsername = await readBotUsername(adminClient);
  const maxOpenUrl = botUsername
    ? `https://max.ru/${encodeURIComponent(botUsername)}`
    : "https://max.ru/";

  if (maxLink?.max_user_id != null) {
    await adminClient
      .from("employee_max_login_attempts")
      .update({
        max_user_id: String(maxLink.max_user_id),
        state: "pending",
        updated_at: new Date().toISOString(),
      })
      .eq("id", attempt.id);
    await requestOtp(supabaseUrl, anonKey, phone);
    return {
      ok: true,
      status: "waiting_max",
      attempt_token: attempt.clientToken,
      max_url: maxOpenUrl,
      expires_at: attempt.expiresAt,
    };
  }

  const connectToken = randomToken();
  const connectExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const { error: tokenError } = await adminClient
    .from("employee_max_link_tokens")
    .insert({
      token_hash: await sha256(connectToken),
      company_id: account.company_id,
      person_id: account.person_id,
      user_id: account.user_id,
      phone_e164: account.phone_e164,
      expires_at: connectExpiresAt,
      login_attempt_id: attempt.id,
    });
  if (tokenError) throw tokenError;

  await adminClient
    .from("employee_max_login_attempts")
    .update({ state: "linking", updated_at: new Date().toISOString() })
    .eq("id", attempt.id);

  return {
    ok: true,
    status: "link_required",
    attempt_token: attempt.clientToken,
    max_url: botUsername
      ? `https://max.ru/${encodeURIComponent(botUsername)}?start=${encodeURIComponent(connectToken)}`
      : maxOpenUrl,
    expires_at: attempt.expiresAt,
  };
}

async function createSessionForAttempt({
  adminClient,
  anonKey,
  supabaseUrl,
  serviceRoleKey,
  attempt,
}: {
  // deno-lint-ignore no-explicit-any
  adminClient: any;
  anonKey: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  attempt: LoginAttempt;
}) {
  const otpCiphertext = String(attempt.otp_ciphertext ?? "");
  if (!otpCiphertext) throw new Error("Подтверждение MAX ещё не готово");
  const otp = await decryptValue(otpCiphertext, serviceRoleKey);
  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await authClient.auth.verifyOtp({
    phone: attempt.phone_e164,
    token: otp,
    type: "sms",
  });
  if (error) throw error;
  if (!data.session || !data.user) {
    throw new Error("Не удалось создать сессию сотрудника");
  }

  const sessionPayload = JSON.stringify({
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
    expires_at: data.session.expires_at,
    expires_in: data.session.expires_in,
    token_type: data.session.token_type,
    user_id: data.user.id,
  });
  const sessionCiphertext = await encryptValue(sessionPayload, serviceRoleKey);
  const sessionReadyAt = new Date().toISOString();
  const deliveryExpiresAt = new Date(Date.now() + sessionDeliveryLifetimeMs).toISOString();
  const { error: updateError } = await adminClient
    .from("employee_max_login_attempts")
    .update({
      state: "session_ready",
      otp_ciphertext: null,
      session_ciphertext: sessionCiphertext,
      session_ready_at: sessionReadyAt,
      expires_at: deliveryExpiresAt,
      updated_at: sessionReadyAt,
    })
    .eq("id", attempt.id)
    .eq("state", "confirmed");
  if (updateError) throw updateError;
  return JSON.parse(sessionPayload) as Record<string, unknown>;
}

async function pollLogin({
  adminClient,
  anonKey,
  supabaseUrl,
  serviceRoleKey,
  attemptToken,
}: {
  // deno-lint-ignore no-explicit-any
  adminClient: any;
  anonKey: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  attemptToken: string;
}) {
  if (attemptToken.length < 24 || attemptToken.length > 128) {
    throw new Error("Попытка входа некорректна");
  }
  const { data, error } = await adminClient
    .from("employee_max_login_attempts")
    .select(
      "id, company_id, person_id, user_id, phone_e164, max_user_id, state, otp_ciphertext, session_ciphertext, expires_at",
    )
    .eq("client_token_hash", await sha256(attemptToken))
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("Попытка входа не найдена");
  const attempt = data as LoginAttempt;

  if (new Date(attempt.expires_at).getTime() <= Date.now()) {
    await adminClient
      .from("employee_max_login_attempts")
      .update({ state: "expired", updated_at: new Date().toISOString() })
      .eq("id", attempt.id);
    return { ok: false, status: "expired", error: "Время подтверждения истекло" };
  }

  if (attempt.state === "linking") {
    const maxLink = await readActiveMaxLink(adminClient, attempt);
    if (maxLink?.max_user_id != null) {
      const { data: claimed } = await adminClient
        .from("employee_max_login_attempts")
        .update({
          state: "pending",
          max_user_id: String(maxLink.max_user_id),
          updated_at: new Date().toISOString(),
        })
        .eq("id", attempt.id)
        .eq("state", "linking")
        .select("id")
        .maybeSingle();
      if (claimed) await requestOtp(supabaseUrl, anonKey, attempt.phone_e164);
      return { ok: true, status: "waiting_max" };
    }
    return { ok: true, status: "link_required" };
  }

  if (attempt.state === "pending") {
    return { ok: true, status: "waiting_max" };
  }
  if (attempt.state === "code_ready") {
    return { ok: true, status: "waiting_confirmation" };
  }
  if (attempt.state === "confirmed") {
    const session = await createSessionForAttempt({
      adminClient,
      anonKey,
      supabaseUrl,
      serviceRoleKey,
      attempt,
    });
    return { ok: true, status: "signed_in", session };
  }
  if (attempt.state === "session_ready") {
    const encrypted = String(attempt.session_ciphertext ?? "");
    if (!encrypted) throw new Error("Сессия входа повреждена");
    const session = JSON.parse(
      await decryptValue(encrypted, serviceRoleKey),
    ) as Record<string, unknown>;
    return { ok: true, status: "signed_in", session };
  }
  return { ok: false, status: "expired", error: "Попытка входа завершена" };
}

async function confirmLogin({
  adminClient,
  confirmToken,
}: {
  // deno-lint-ignore no-explicit-any
  adminClient: any;
  confirmToken: string;
}) {
  if (confirmToken.length < 24 || confirmToken.length > 128) {
    return html("<h2>Ссылка подтверждения некорректна</h2>", 400);
  }
  const { data, error } = await adminClient
    .from("employee_max_login_attempts")
    .select("id, state, expires_at")
    .eq("confirm_token_hash", await sha256(confirmToken))
    .maybeSingle();
  if (error) throw error;
  if (!data || new Date(data.expires_at).getTime() <= Date.now()) {
    return html("<h2>Ссылка подтверждения истекла</h2><p>Вернитесь в AppСтрой и начните вход заново.</p>", 410);
  }
  if (data.state === "code_ready") {
    const { error: updateError } = await adminClient
      .from("employee_max_login_attempts")
      .update({
        state: "confirmed",
        confirmed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", data.id)
      .eq("state", "code_ready");
    if (updateError) throw updateError;
  } else if (!["confirmed", "session_ready"].includes(String(data.state))) {
    return html("<h2>Подтверждение пока недоступно</h2><p>Запросите вход ещё раз в AppСтрой.</p>", 409);
  }

  const appUrl =
    Deno.env.get("APP_PUBLIC_URL")?.trim() ||
    "https://13off.github.io/appstroy-web/";
  return html(`<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Вход подтверждён</title><style>
body{margin:0;min-height:100vh;display:grid;place-items:center;background:#111827;color:#f9fafb;font-family:system-ui,sans-serif;padding:24px;box-sizing:border-box}
main{max-width:440px;text-align:center;background:#1f2937;border:1px solid #374151;border-radius:28px;padding:32px}
h1{font-size:25px;margin:0 0 12px}p{color:#cbd5e1;line-height:1.5}a{display:inline-block;margin-top:14px;padding:13px 20px;border-radius:15px;background:#f59e0b;color:#111827;text-decoration:none;font-weight:800}
</style></head><body><main><h1>Вход подтверждён</h1><p>Вернитесь в AppСтрой. Кабинет откроется автоматически.</p><a href="${appUrl.replaceAll('"', "&quot;")}">Открыть AppСтрой</a></main></body></html>`);
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Вход через MAX не настроен" }, 500);
    }
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const url = new URL(request.url);
    if (request.method === "GET") {
      return await confirmLogin({
        adminClient,
        confirmToken: url.searchParams.get("confirm")?.trim() ?? "",
      });
    }
    if (request.method !== "POST") {
      return json({ error: "Метод не поддерживается" }, 405);
    }

    const input = await request.json();
    const action = String(input.action ?? "request").trim();
    if (action === "request") {
      const phone = normalizePhone(input.phone);
      if (!phone) return json({ ok: false, error: "Некорректный номер телефона" }, 400);
      return json(
        await startLogin({ adminClient, supabaseUrl, anonKey, phone }),
      );
    }
    if (action === "poll") {
      return json(
        await pollLogin({
          adminClient,
          anonKey,
          supabaseUrl,
          serviceRoleKey,
          attemptToken: String(input.attempt_token ?? "").trim(),
        }),
      );
    }
    return json({ error: "Неизвестное действие" }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Employee MAX one-tap login failed", {
      name: error instanceof Error ? error.name : "UnknownError",
      reason: message.includes("Слишком много") ? "rate_limit" : "login_failed",
    });
    const status = message.includes("Слишком много") ? 429 : 400;
    return json({ ok: false, error: message || "Не удалось войти через MAX" }, status);
  }
});
