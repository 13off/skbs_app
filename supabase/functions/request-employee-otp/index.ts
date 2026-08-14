import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const maxRequestBytes = 4 * 1024;

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
  if (
    digits.length === 11 && (digits.startsWith("7") || digits.startsWith("8"))
  ) {
    return `+7${digits.slice(1)}`;
  }
  if (digits.length === 10) return `+7${digits}`;
  return "";
}

function serviceKey(): string {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, string>;
      return parsed.default ?? Object.values(parsed)[0] ?? "";
    } catch (_) {
      // Fall back to the legacy service-role environment variable.
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function clientIp(request: Request): string {
  return request.headers.get("cf-connecting-ip")?.trim() ||
    request.headers.get("x-real-ip")?.trim() ||
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    "unknown";
}

async function consumeLimit(
  adminClient: { rpc: unknown },
  scope: string,
  key: string,
  limit: number,
  windowSeconds: number,
): Promise<boolean> {
  const pepper = Deno.env.get("EDGE_RATE_LIMIT_PEPPER") ?? "appstroy";
  const rpc = adminClient.rpc as (
    name: string,
    params: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: { message?: string } | null }>;
  const { data, error } = await rpc("consume_edge_rate_limit", {
    p_scope: scope,
    p_key_hash: await sha256(`${pepper}:${key}`),
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  if (error) throw error;
  return data === true;
}

function accepted() {
  return json({ ok: true, channel: "max" });
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
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Вход сотрудников не настроен" }, 500);
    }

    const contentType = request.headers.get("content-type")?.toLowerCase() ??
      "";
    if (!contentType.startsWith("application/json")) {
      return json({ error: "Ожидается JSON" }, 415);
    }
    const declaredLength = Number(request.headers.get("content-length") ?? 0);
    if (Number.isFinite(declaredLength) && declaredLength > maxRequestBytes) {
      return json({ error: "Запрос слишком большой" }, 413);
    }
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const ipAllowed = await consumeLimit(
      adminClient,
      "employee_otp_ip",
      clientIp(request),
      10,
      600,
    );
    if (!ipAllowed) {
      return json({
        ok: false,
        error: "Слишком много запросов. Попробуйте позже",
      }, 429);
    }
    const rawInput = await request.text();
    if (!rawInput || rawInput.length > maxRequestBytes) {
      return json({ error: "Запрос слишком большой" }, 413);
    }
    let input: Record<string, unknown>;
    try {
      input = JSON.parse(rawInput) as Record<string, unknown>;
    } catch (_) {
      return json({ error: "Некорректный JSON" }, 400);
    }
    const phone = normalizePhone(input.phone);
    if (!phone) {
      return json({ ok: false, error: "Некорректный номер телефона" });
    }

    const phoneAllowed = await consumeLimit(
      adminClient,
      "employee_otp_phone",
      phone,
      5,
      900,
    );
    if (!phoneAllowed) {
      return json({
        ok: false,
        error: "Слишком много запросов. Попробуйте позже",
      }, 429);
    }

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
      return accepted();
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
      return accepted();
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
      return accepted();
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error: otpError } = await authClient.auth.signInWithOtp({
      phone,
      options: { shouldCreateUser: false },
    });
    if (otpError) throw otpError;

    return accepted();
  } catch (error) {
    console.error("Employee MAX OTP request failed", {
      name: error instanceof Error ? error.name : "UnknownError",
    });
    return json({ error: "Не удалось отправить код. Попробуйте позже" }, 500);
  }
});
