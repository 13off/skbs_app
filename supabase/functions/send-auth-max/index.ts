import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

type HookPayload = {
  user?: { phone?: string | null };
  sms?: { otp?: string | null };
};

type MaxLink = {
  company_id: string;
  person_id: string;
  user_id: string;
  max_user_id: number | string;
};

function hookError(message: string, status = 500) {
  return new Response(
    JSON.stringify({ error: { http_code: status, message } }),
    {
      status,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
      },
    },
  );
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

function bytesToBase64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function randomToken() {
  return bytesToBase64Url(crypto.getRandomValues(new Uint8Array(32)));
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
    ["encrypt"],
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

async function readSecret(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  envName: string,
  vaultName: string,
) {
  const fromEnvironment = Deno.env.get(envName)?.trim() ?? "";
  if (fromEnvironment) return fromEnvironment;
  const { data, error } = await adminClient.rpc("get_recruitment_secret", {
    p_name: vaultName,
  });
  if (error) throw error;
  return String(data ?? "").trim();
}

async function validateMaxLink(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  phone: string,
): Promise<MaxLink> {
  const { data: links, error: linksError } = await adminClient
    .from("employee_max_links")
    .select("company_id, person_id, user_id, max_user_id")
    .eq("phone_e164", phone)
    .eq("is_active", true)
    .limit(10);
  if (linksError) throw linksError;

  const uniqueUsers = new Set(
    (links ?? []).map((row: MaxLink) => String(row.max_user_id)),
  );
  if (!links?.length || uniqueUsers.size !== 1) {
    throw new Error("MAX не подключён к кабинету сотрудника");
  }

  for (const link of links as MaxLink[]) {
    const [{ data: account }, { data: company }, { data: profile }] =
      await Promise.all([
        adminClient
          .from("employee_account_links")
          .select("user_id")
          .eq("company_id", link.company_id)
          .eq("person_id", link.person_id)
          .eq("user_id", link.user_id)
          .eq("phone_e164", phone)
          .eq("is_active", true)
          .maybeSingle(),
        adminClient
          .from("companies")
          .select("id")
          .eq("id", link.company_id)
          .eq("status", "active")
          .maybeSingle(),
        adminClient
          .from("user_profiles")
          .select("id")
          .eq("id", link.user_id)
          .eq("role", "employee")
          .eq("is_active", true)
          .maybeSingle(),
      ]);
    if (account && company && profile) return link;
  }

  throw new Error("Доступ сотрудника отключён");
}

async function sendMaxMessage({
  maxBotToken,
  maxUserId,
  body,
}: {
  maxBotToken: string;
  maxUserId: string;
  body: string;
}) {
  const hosts = [
    "https://platform-api2.max.ru",
    "https://platform-api.max.ru",
  ];
  let lastError: unknown = null;

  for (const host of hosts) {
    const endpoint = new URL("/messages", host);
    endpoint.searchParams.set("user_id", maxUserId);
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: maxBotToken,
          "Content-Type": "application/json; charset=utf-8",
        },
        body,
        signal: AbortSignal.timeout(7000),
      });
      if (response.ok || response.status < 500) return response;
      lastError = new Error(`MAX HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
      console.warn("MAX endpoint unavailable, trying fallback", {
        host,
        name: error instanceof Error ? error.name : "UnknownError",
      });
    }
  }

  throw lastError instanceof Error
    ? lastError
    : new Error("MAX API недоступен");
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return hookError("Метод не поддерживается", 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return hookError("Сервис входа через MAX не настроен", 500);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const [hookSecret, maxBotToken] = await Promise.all([
      readSecret(adminClient, "SEND_SMS_HOOK_SECRET", "send_sms_hook_secret"),
      readSecret(adminClient, "MAX_BOT_TOKEN", "max_bot_token"),
    ]);
    if (!hookSecret || !maxBotToken) {
      return hookError("Вход через MAX ещё не активирован", 503);
    }

    const rawPayload = await request.text();
    const webhook = new Webhook(hookSecret.replace(/^v1,whsec_/, ""));
    const payload = webhook.verify(
      rawPayload,
      Object.fromEntries(request.headers),
    ) as HookPayload;

    const phone = normalizePhone(payload.user?.phone);
    const otp = String(payload.sms?.otp ?? "").trim();
    if (!phone || !/^\d{6}$/.test(otp)) {
      return hookError("Некорректные данные для отправки кода", 400);
    }

    const maxLink = await validateMaxLink(adminClient, phone);
    const nowIso = new Date().toISOString();
    const { data: attempts, error: attemptError } = await adminClient
      .from("employee_max_login_attempts")
      .select("id, company_id, person_id, user_id, expires_at")
      .eq("phone_e164", phone)
      .eq("company_id", maxLink.company_id)
      .eq("person_id", maxLink.person_id)
      .eq("user_id", maxLink.user_id)
      .eq("state", "pending")
      .gt("expires_at", nowIso)
      .order("created_at", { ascending: false })
      .limit(1);
    if (attemptError) throw attemptError;

    const attempt = attempts?.[0];
    let messageBody: string;
    if (attempt) {
      const confirmToken = randomToken();
      const { error: updateError } = await adminClient
        .from("employee_max_login_attempts")
        .update({
          confirm_token_hash: await sha256(confirmToken),
          otp_ciphertext: await encryptValue(otp, serviceRoleKey),
          max_user_id: String(maxLink.max_user_id),
          state: "code_ready",
          updated_at: nowIso,
        })
        .eq("id", attempt.id)
        .eq("state", "pending");
      if (updateError) throw updateError;

      const confirmUrl = new URL(
        "/functions/v1/employee-max-login",
        supabaseUrl,
      );
      confirmUrl.searchParams.set("confirm", confirmToken);
      messageBody = JSON.stringify({
        text: "Запрошен вход в AppСтрой. Нажмите кнопку ниже, чтобы подтвердить вход в свой кабинет.\n\nЕсли это были не вы — ничего не нажимайте.",
        attachments: [
          {
            type: "inline_keyboard",
            payload: {
              buttons: [
                [
                  {
                    type: "link",
                    text: "Подтвердить вход",
                    url: confirmUrl.toString(),
                  },
                ],
              ],
            },
          },
        ],
      });
    } else {
      const appUrl =
        Deno.env.get("APP_PUBLIC_URL")?.trim() ||
        "https://13off.github.io/appstroy-web/";
      messageBody = JSON.stringify({
        text: `Код входа в AppСтрой: **${otp}**\n\nКод действует ограниченное время. Никому его не сообщайте.`,
        format: "markdown",
        attachments: [
          {
            type: "inline_keyboard",
            payload: {
              buttons: [
                [
                  {
                    type: "link",
                    text: "Открыть AppСтрой",
                    url: appUrl,
                  },
                ],
              ],
            },
          },
        ],
      });
    }

    const maxResponse = await sendMaxMessage({
      maxBotToken,
      maxUserId: String(maxLink.max_user_id),
      body: messageBody,
    });

    if (!maxResponse.ok) {
      console.error("MAX rejected employee auth message", {
        httpStatus: maxResponse.status,
      });
      return hookError("MAX не смог доставить подтверждение входа", 502);
    }

    return new Response("{}", {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("MAX auth hook failed", {
      name: error instanceof Error ? error.name : "UnknownError",
      reason: message.includes("MAX не подключён")
        ? "max_not_connected"
        : "delivery_failed",
    });
    const status = message.includes("MAX не подключён") ? 403 : 500;
    return hookError(message || "Не удалось подтвердить вход через MAX", status);
  }
});
