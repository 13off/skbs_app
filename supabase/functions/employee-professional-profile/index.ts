import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class HttpError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

type EmployeeIdentity = {
  companyId: string;
  personId: string;
  userId: string;
};

type ProfessionalInput = {
  grade: string;
  experienceYears: number;
  skills: string[];
  about: string;
  preferredCities: string[];
  readyForRotation: boolean;
  openToOffers: boolean;
  desiredDailyRate: number | null;
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

function cleanText(value: unknown, maxLength: number) {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function cleanParagraph(value: unknown, maxLength: number) {
  return String(value ?? "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim()
    .slice(0, maxLength);
}

function cleanList(value: unknown, maxItems: number, maxItemLength: number) {
  if (!Array.isArray(value)) return [];
  const result: string[] = [];
  const seen = new Set<string>();
  for (const raw of value) {
    const item = cleanText(raw, maxItemLength);
    const key = item.toLocaleLowerCase("ru");
    if (!item || seen.has(key)) continue;
    seen.add(key);
    result.push(item);
    if (result.length >= maxItems) break;
  }
  return result;
}

function finiteNumber(value: unknown, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseProfessionalInput(input: Record<string, unknown>): ProfessionalInput {
  const experienceYears = Math.round(
    Math.min(70, Math.max(0, finiteNumber(input.experience_years))) * 10,
  ) / 10;

  let desiredDailyRate: number | null = null;
  if (input.desired_daily_rate !== null && input.desired_daily_rate !== undefined) {
    const parsed = Math.round(finiteNumber(input.desired_daily_rate, -1));
    if (parsed < 0 || parsed > 10_000_000) {
      throw new HttpError("Желаемая ставка указана некорректно", 400);
    }
    desiredDailyRate = parsed;
  }

  return {
    grade: cleanText(input.grade, 40),
    experienceYears,
    skills: cleanList(input.skills, 20, 50),
    about: cleanParagraph(input.about, 800),
    preferredCities: cleanList(input.preferred_cities, 12, 80),
    readyForRotation: input.ready_for_rotation === true,
    openToOffers: input.open_to_offers === true,
    desiredDailyRate,
  };
}

async function employeeIdentity(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  userId: string,
): Promise<EmployeeIdentity> {
  const { data: userProfile, error: profileError } = await adminClient
    .from("user_profiles")
    .select("id, role, active_company_id, is_active")
    .eq("id", userId)
    .eq("role", "employee")
    .eq("is_active", true)
    .maybeSingle();
  if (profileError) throw profileError;
  if (!userProfile?.active_company_id) {
    throw new HttpError("Кабинет сотрудника отключён", 403);
  }

  const { data: link, error: linkError } = await adminClient
    .from("employee_account_links")
    .select("company_id, person_id, user_id")
    .eq("company_id", userProfile.active_company_id)
    .eq("user_id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (linkError) throw linkError;
  if (!link) throw new HttpError("Связь с рабочей карточкой не найдена", 403);

  return {
    companyId: String(link.company_id),
    personId: String(link.person_id),
    userId: String(link.user_id),
  };
}

async function readVerifiedProfile(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  identity: EmployeeIdentity,
) {
  const [{ data: employees, error: employeesError }, summaryResult] =
    await Promise.all([
      adminClient
        .from("employees")
        .select(
          "id, fio, position, object_name, daily_rate, is_active, archived_at, updated_at",
        )
        .eq("company_id", identity.companyId)
        .eq("person_id", identity.personId)
        .is("archived_at", null)
        .order("is_active", { ascending: false })
        .order("updated_at", { ascending: false }),
      adminClient.rpc("employee_professional_summary", {
        p_company_id: identity.companyId,
        p_person_id: identity.personId,
      }),
    ]);
  if (employeesError) throw employeesError;
  if (summaryResult.error) throw summaryResult.error;
  if (!employees || employees.length === 0) {
    throw new HttpError("Рабочая карточка сотрудника не найдена", 404);
  }

  const activeEmployee =
    employees.find((row: { is_active?: boolean }) => row.is_active === true) ??
    employees[0];
  const summary = summaryResult.data && typeof summaryResult.data === "object"
    ? summaryResult.data as Record<string, unknown>
    : {};
  const rawObjects = Array.isArray(summary.object_names)
    ? summary.object_names
    : [];

  return {
    full_name: cleanText(activeEmployee.fio, 180) || "Сотрудник",
    profession: cleanText(activeEmployee.position, 120),
    current_object: cleanText(activeEmployee.object_name, 160),
    current_daily_rate: Math.max(
      0,
      Math.trunc(finiteNumber(activeEmployee.daily_rate)),
    ),
    object_names: cleanList(rawObjects, 50, 160),
    total_shifts: finiteNumber(summary.total_shifts),
    total_hours: finiteNumber(summary.total_hours),
    completed_tasks: Math.max(0, Math.trunc(finiteNumber(summary.completed_tasks))),
    documents: Math.max(0, Math.trunc(finiteNumber(summary.documents))),
    first_work_date: cleanText(summary.first_work_date, 20),
  };
}

async function readProfessionalProfile(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  identity: EmployeeIdentity,
) {
  const { data, error } = await adminClient
    .from("employee_professional_profiles")
    .select(
      "grade, experience_years, skills, about, preferred_cities, ready_for_rotation, open_to_offers, desired_daily_rate, updated_at",
    )
    .eq("company_id", identity.companyId)
    .eq("person_id", identity.personId)
    .eq("user_id", identity.userId)
    .maybeSingle();
  if (error) throw error;

  return {
    grade: cleanText(data?.grade, 40),
    experience_years: finiteNumber(data?.experience_years),
    skills: cleanList(data?.skills, 20, 50),
    about: cleanParagraph(data?.about, 800),
    preferred_cities: cleanList(data?.preferred_cities, 12, 80),
    ready_for_rotation: data?.ready_for_rotation === true,
    open_to_offers: data?.open_to_offers === true,
    desired_daily_rate: data?.desired_daily_rate == null
      ? null
      : Math.max(0, Math.trunc(finiteNumber(data.desired_daily_rate))),
    updated_at: cleanText(data?.updated_at, 40),
  };
}

async function passportPayload(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  identity: EmployeeIdentity,
) {
  const [professional, verified] = await Promise.all([
    readProfessionalProfile(adminClient, identity),
    readVerifiedProfile(adminClient, identity),
  ]);
  return { ok: true, professional, verified };
}

async function updateProfessionalProfile(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  identity: EmployeeIdentity,
  input: Record<string, unknown>,
) {
  const clean = parseProfessionalInput(input);
  const now = new Date().toISOString();
  const { error } = await adminClient
    .from("employee_professional_profiles")
    .upsert(
      {
        company_id: identity.companyId,
        person_id: identity.personId,
        user_id: identity.userId,
        grade: clean.grade,
        experience_years: clean.experienceYears,
        skills: clean.skills,
        about: clean.about,
        preferred_cities: clean.preferredCities,
        ready_for_rotation: clean.readyForRotation,
        open_to_offers: clean.openToOffers,
        desired_daily_rate: clean.desiredDailyRate,
        updated_at: now,
      },
      { onConflict: "company_id,person_id" },
    );
  if (error) throw error;
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
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new HttpError("Паспорт специалиста не настроен", 500);
    }
    if (!authorization) throw new HttpError("Требуется вход сотрудника", 401);

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) throw new HttpError("Требуется повторный вход", 401);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const identity = await employeeIdentity(adminClient, user.id);

    let input: Record<string, unknown> = {};
    try {
      const raw = await request.json();
      if (raw && typeof raw === "object") input = raw as Record<string, unknown>;
    } catch {
      input = {};
    }

    const action = cleanText(input.action, 20) || "fetch";
    if (action === "update") {
      const rawProfile = input.professional;
      const professional = rawProfile && typeof rawProfile === "object"
        ? rawProfile as Record<string, unknown>
        : {};
      await updateProfessionalProfile(adminClient, identity, professional);
    } else if (action !== "fetch") {
      throw new HttpError("Неизвестное действие", 400);
    }

    return json(await passportPayload(adminClient, identity));
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : String(error);
    console.error("Employee professional passport failed", {
      status,
      reason: status >= 500 ? "server_error" : "request_rejected",
    });
    return json(
      { error: message || "Не удалось загрузить паспорт специалиста" },
      status,
    );
  }
});
