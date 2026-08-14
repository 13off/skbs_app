import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type EmployeeAccount = {
  company_id: string;
  person_id: string;
  user_id: string;
  phone_e164: string;
};

type RecruitmentIdentity = {
  external_user_id?: string | number | null;
  external_chat_id?: string | number | null;
  external_username?: string | null;
  phone?: string | null;
  updated_at?: string | null;
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

function parseMaxId(value: unknown) {
  const text = String(value ?? "").trim();
  return /^\d{1,19}$/.test(text) ? text : "";
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function randomToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
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

async function readMaxLink(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  account: Pick<EmployeeAccount, "company_id" | "person_id">,
) {
  const { data, error } = await adminClient
    .from("employee_max_links")
    .select(
      "company_id, person_id, user_id, phone_e164, max_user_id, max_chat_id, max_username, source, is_active, linked_at",
    )
    .eq("company_id", account.company_id)
    .eq("person_id", account.person_id)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function syncFromRecruitment(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  account: EmployeeAccount,
) {
  const current = await readMaxLink(adminClient, account);
  if (
    current &&
    normalizePhone(current.phone_e164) === account.phone_e164 &&
    parseMaxId(current.max_user_id)
  ) {
    if (current.is_active !== true || current.user_id !== account.user_id) {
      const { error } = await adminClient
        .from("employee_max_links")
        .update({
          user_id: account.user_id,
          phone_e164: account.phone_e164,
          is_active: true,
          updated_at: new Date().toISOString(),
        })
        .eq("company_id", account.company_id)
        .eq("person_id", account.person_id);
      if (error) throw error;
    }
    return await readMaxLink(adminClient, account);
  }

  const { data: rawApplications, error: applicationsError } = await adminClient
    .from("recruitment_applications")
    .select(
      "external_user_id, external_chat_id, external_username, phone, updated_at",
    )
    .eq("company_id", account.company_id)
    .eq("source", "max")
    .order("updated_at", { ascending: false })
    .limit(1000);
  if (applicationsError) throw applicationsError;

  const applications = (rawApplications ?? []) as RecruitmentIdentity[];
  const matching = applications.filter(
    (row: RecruitmentIdentity) =>
      normalizePhone(row.phone) === account.phone_e164 &&
      parseMaxId(row.external_user_id) !== "",
  );
  const uniqueMaxUsers = new Map<string, RecruitmentIdentity>();
  for (const row of matching) {
    const id = parseMaxId(row.external_user_id);
    if (!uniqueMaxUsers.has(id)) uniqueMaxUsers.set(id, row);
  }
  if (uniqueMaxUsers.size !== 1) return null;

  const candidate = Array.from(uniqueMaxUsers.values())[0];
  const now = new Date().toISOString();
  const { error: writeError } = await adminClient
    .from("employee_max_links")
    .upsert(
      {
        company_id: account.company_id,
        person_id: account.person_id,
        user_id: account.user_id,
        phone_e164: account.phone_e164,
        max_user_id: parseMaxId(candidate.external_user_id),
        max_chat_id: parseMaxId(candidate.external_chat_id) || null,
        max_username: String(candidate.external_username ?? "").trim(),
        source: "recruitment",
        is_active: true,
        linked_at: now,
        updated_at: now,
      },
      { onConflict: "company_id,person_id" },
    );
  if (writeError) throw writeError;
  return await readMaxLink(adminClient, account);
}

async function createConnectToken(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  account: EmployeeAccount,
  actorId: string,
) {
  const { error: deleteError } = await adminClient
    .from("employee_max_link_tokens")
    .delete()
    .eq("company_id", account.company_id)
    .eq("person_id", account.person_id)
    .is("used_at", null);
  if (deleteError) throw deleteError;

  const token = randomToken();
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const { error: insertError } = await adminClient
    .from("employee_max_link_tokens")
    .insert({
      token_hash: await sha256(token),
      company_id: account.company_id,
      person_id: account.person_id,
      user_id: account.user_id,
      phone_e164: account.phone_e164,
      expires_at: expiresAt,
      created_by: actorId,
    });
  if (insertError) throw insertError;

  const botUsername = await readBotUsername(adminClient);
  return {
    max_connect_code: token,
    max_connect_url: botUsername
      ? `https://max.ru/${encodeURIComponent(botUsername)}?start=${encodeURIComponent(token)}`
      : "",
    max_connect_expires_at: expiresAt,
  };
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
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
      return json({ error: "Управление MAX не настроено" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user: actor },
      error: actorError,
    } = await userClient.auth.getUser();
    if (actorError || !actor) {
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const input = await request.json();
    const action = String(input.action ?? "status").trim();
    const employeeId = String(input.employee_id ?? "").trim();
    if (!employeeId) return json({ error: "Не выбран сотрудник" }, 400);
    if (!new Set(["status", "prepare", "disable"]).has(action)) {
      return json({ error: "Неизвестное действие" }, 400);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: employee, error: employeeError } = await adminClient
      .from("employees")
      .select("id, company_id, person_id")
      .eq("id", employeeId)
      .single();
    if (employeeError) throw employeeError;
    const companyId = String(employee.company_id ?? "").trim();
    const personId = String(employee.person_id ?? "").trim();
    if (!companyId || !personId) {
      return json({ error: "Карточка сотрудника не связана с человеком" }, 409);
    }

    const { data: membership, error: membershipError } = await adminClient
      .from("company_memberships")
      .select("role")
      .eq("company_id", companyId)
      .eq("user_id", actor.id)
      .in("role", ["owner", "admin", "developer"])
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) {
      return json({ error: "Управлять MAX может только руководитель" }, 403);
    }

    const { data: rawAccount, error: accountError } = await adminClient
      .from("employee_account_links")
      .select("company_id, person_id, user_id, phone_e164, is_active")
      .eq("company_id", companyId)
      .eq("person_id", personId)
      .maybeSingle();
    if (accountError) throw accountError;

    if (action === "disable") {
      const now = new Date().toISOString();
      const [{ error: linkError }, { error: tokenError }] = await Promise.all([
        adminClient
          .from("employee_max_links")
          .update({ is_active: false, updated_at: now })
          .eq("company_id", companyId)
          .eq("person_id", personId),
        adminClient
          .from("employee_max_link_tokens")
          .delete()
          .eq("company_id", companyId)
          .eq("person_id", personId)
          .is("used_at", null),
      ]);
      if (linkError) throw linkError;
      if (tokenError) throw tokenError;
      return json({ ok: true, max_connected: false, max_ready: false });
    }

    if (!rawAccount || rawAccount.is_active !== true) {
      return json({ ok: true, max_connected: false, max_ready: false });
    }

    const account: EmployeeAccount = {
      company_id: String(rawAccount.company_id),
      person_id: String(rawAccount.person_id),
      user_id: String(rawAccount.user_id),
      phone_e164: normalizePhone(rawAccount.phone_e164),
    };
    if (!account.phone_e164) {
      return json({ error: "У аккаунта сотрудника некорректный номер" }, 409);
    }

    const maxLink = await syncFromRecruitment(adminClient, account);
    if (maxLink?.is_active === true) {
      return json({
        ok: true,
        max_connected: true,
        max_ready: true,
        max_username: String(maxLink.max_username ?? "").trim(),
        max_source: String(maxLink.source ?? "").trim(),
      });
    }

    if (action === "status") {
      return json({ ok: true, max_connected: false, max_ready: true });
    }

    return json({
      ok: true,
      max_connected: false,
      max_ready: true,
      ...(await createConnectToken(adminClient, account, actor.id)),
    });
  } catch (error) {
    console.error("Employee MAX management failed", {
      name: error instanceof Error ? error.name : "UnknownError",
    });
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message || "Не удалось настроить MAX" }, 500);
  }
});
