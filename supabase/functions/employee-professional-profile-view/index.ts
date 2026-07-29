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
      throw new HttpError("Просмотр паспорта специалиста не настроен", 500);
    }
    if (!authorization) throw new HttpError("Требуется вход", 401);

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

    const { data: viewer, error: viewerError } = await adminClient
      .from("user_profiles")
      .select("id, role, active_company_id, is_active")
      .eq("id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (viewerError) throw viewerError;
    if (!viewer?.active_company_id) {
      throw new HttpError("Компания пользователя не определена", 403);
    }
    if (viewer.role !== "admin" && viewer.role !== "developer") {
      throw new HttpError("Недостаточно прав для просмотра паспорта", 403);
    }

    let input: Record<string, unknown> = {};
    try {
      const raw = await request.json();
      if (raw && typeof raw === "object") input = raw as Record<string, unknown>;
    } catch {
      input = {};
    }
    const employeeId = cleanText(input.employee_id, 80);
    if (!employeeId) throw new HttpError("Сотрудник не выбран", 400);

    const companyId = String(viewer.active_company_id);
    const { data: selectedEmployee, error: selectedError } = await adminClient
      .from("employees")
      .select("id, person_id")
      .eq("id", employeeId)
      .eq("company_id", companyId)
      .maybeSingle();
    if (selectedError) throw selectedError;
    if (!selectedEmployee?.person_id) {
      throw new HttpError("Единая карточка сотрудника не найдена", 404);
    }
    const personId = String(selectedEmployee.person_id);

    const [employeesResult, summaryResult, professionalResult] = await Promise.all([
      adminClient
        .from("employees")
        .select(
          "id, fio, position, object_name, daily_rate, is_active, archived_at, updated_at",
        )
        .eq("company_id", companyId)
        .eq("person_id", personId)
        .order("is_active", { ascending: false })
        .order("updated_at", { ascending: false }),
      adminClient.rpc("employee_professional_summary", {
        p_company_id: companyId,
        p_person_id: personId,
      }),
      adminClient
        .from("employee_professional_profiles")
        .select(
          "grade, experience_years, skills, about, preferred_cities, ready_for_rotation, open_to_offers, desired_daily_rate, updated_at",
        )
        .eq("company_id", companyId)
        .eq("person_id", personId)
        .maybeSingle(),
    ]);

    if (employeesResult.error) throw employeesResult.error;
    if (summaryResult.error) throw summaryResult.error;
    if (professionalResult.error) throw professionalResult.error;

    const employees = employeesResult.data ?? [];
    if (employees.length === 0) {
      throw new HttpError("Рабочая карточка сотрудника не найдена", 404);
    }
    const activeEmployee =
      employees.find((row: { is_active?: boolean }) => row.is_active === true) ??
      employees[0];
    const summary = summaryResult.data && typeof summaryResult.data === "object"
      ? summaryResult.data as Record<string, unknown>
      : {};
    const professional = professionalResult.data;

    return json({
      ok: true,
      professional: {
        grade: cleanText(professional?.grade, 40),
        experience_years: finiteNumber(professional?.experience_years),
        skills: cleanList(professional?.skills, 20, 50),
        about: cleanParagraph(professional?.about, 800),
        preferred_cities: cleanList(professional?.preferred_cities, 12, 80),
        ready_for_rotation: professional?.ready_for_rotation === true,
        open_to_offers: professional?.open_to_offers === true,
        desired_daily_rate: professional?.desired_daily_rate == null
          ? null
          : Math.max(0, Math.trunc(finiteNumber(professional.desired_daily_rate))),
        updated_at: cleanText(professional?.updated_at, 40),
      },
      verified: {
        full_name: cleanText(activeEmployee.fio, 180) || "Сотрудник",
        profession: cleanText(activeEmployee.position, 120),
        current_object: cleanText(activeEmployee.object_name, 160),
        current_daily_rate: Math.max(
          0,
          Math.trunc(finiteNumber(activeEmployee.daily_rate)),
        ),
        object_names: cleanList(summary.object_names, 50, 160),
        total_shifts: finiteNumber(summary.total_shifts),
        total_hours: finiteNumber(summary.total_hours),
        completed_tasks: Math.max(
          0,
          Math.trunc(finiteNumber(summary.completed_tasks)),
        ),
        documents: Math.max(0, Math.trunc(finiteNumber(summary.documents))),
        first_work_date: cleanText(summary.first_work_date, 20),
      },
    });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : String(error);
    console.error("Employee professional passport view failed", {
      status,
      reason: status >= 500 ? "server_error" : "request_rejected",
    });
    return json(
      { error: message || "Не удалось загрузить паспорт специалиста" },
      status,
    );
  }
});
