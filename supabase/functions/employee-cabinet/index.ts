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

function numberValue(value: unknown) {
  const result = Number(value ?? 0);
  return Number.isFinite(result) ? result : 0;
}

function isoDate(year: number, monthIndex: number, day: number) {
  return new Date(Date.UTC(year, monthIndex, day)).toISOString().slice(0, 10);
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
      return json({ error: "Личный кабинет сотрудника не настроен" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: profile, error: profileError } = await adminClient
      .from("user_profiles")
      .select(
        "id, full_name, phone, role, profession, object_name, active_company_id, is_active, avatar_path",
      )
      .eq("id", user.id)
      .eq("role", "employee")
      .eq("is_active", true)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || !profile.active_company_id) {
      return json(
        { error: "Кабинет сотрудника отключён. Обратитесь к руководителю" },
        403,
      );
    }

    const { data: link, error: linkError } = await adminClient
      .from("employee_account_links")
      .select("company_id, person_id, phone_e164")
      .eq("company_id", profile.active_company_id)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (linkError) throw linkError;
    if (!link) {
      return json(
        { error: "Доступ к кабинету сотрудника не найден" },
        403,
      );
    }

    const { data: employees, error: employeesError } = await adminClient
      .from("employees")
      .select(
        "id, object_id, object_name, fio, position, phone, daily_rate, is_active, archived_at, updated_at",
      )
      .eq("company_id", link.company_id)
      .eq("person_id", link.person_id)
      .is("archived_at", null)
      .order("is_active", { ascending: false })
      .order("updated_at", { ascending: false });
    if (employeesError) throw employeesError;
    if (!employees || employees.length === 0) {
      return json({ error: "Рабочая карточка сотрудника не найдена" }, 404);
    }

    const employeeIds = employees.map((row) => String(row.id));
    const rateByEmployee = new Map<string, number>();
    for (const row of employees) {
      rateByEmployee.set(String(row.id), numberValue(row.daily_rate));
    }

    const now = new Date();
    const year = now.getUTCFullYear();
    const monthIndex = now.getUTCMonth();
    const monthStart = isoDate(year, monthIndex, 1);
    const nextMonthStart = isoDate(year, monthIndex + 1, 1);

    const [attendanceResult, paymentsResult, assigneesResult, formsResult, legalResult] =
      await Promise.all([
        adminClient
          .from("attendance")
          .select("employee_id, work_date, status, shifts, hours")
          .in("employee_id", employeeIds)
          .is("deleted_at", null)
          .gte("work_date", monthStart)
          .lt("work_date", nextMonthStart)
          .order("work_date", { ascending: false }),
        adminClient
          .from("payments")
          .select(
            "id, employee_id, period_year, period_month, payment_date, amount, comment, payment_type",
          )
          .in("employee_id", employeeIds)
          .is("deleted_at", null)
          .order("payment_date", { ascending: false })
          .limit(50),
        adminClient
          .from("task_assignees")
          .select("task_id")
          .in("employee_id", employeeIds),
        adminClient
          .from("recruitment_onboarding_forms")
          .select(
            "id, employee_id, form_code, status, original_name, storage_path, mime_type, updated_at",
          )
          .in("employee_id", employeeIds)
          .order("updated_at", { ascending: false }),
        adminClient
          .from("legal_documents")
          .select(
            "id, employee_id, title, document_type, status, document_number, updated_at",
          )
          .in("employee_id", employeeIds)
          .is("archived_at", null)
          .order("updated_at", { ascending: false }),
      ]);

    if (attendanceResult.error) throw attendanceResult.error;
    if (paymentsResult.error) throw paymentsResult.error;
    if (assigneesResult.error) throw assigneesResult.error;
    if (formsResult.error) throw formsResult.error;
    if (legalResult.error) throw legalResult.error;

    const taskIds = Array.from(
      new Set((assigneesResult.data ?? []).map((row) => String(row.task_id))),
    );
    let tasks: Record<string, unknown>[] = [];
    if (taskIds.length > 0) {
      const { data, error } = await adminClient
        .from("tasks")
        .select(
          "id, task_date, object_name, axes, work, status, not_done_comment, photo_requirements_enforced, updated_at",
        )
        .in("id", taskIds)
        .is("deleted_at", null)
        .order("task_date", { ascending: false })
        .limit(50);
      if (error) throw error;
      tasks = data ?? [];
    }

    let shifts = 0;
    let hours = 0;
    let estimatedAccrued = 0;
    for (const row of attendanceResult.data ?? []) {
      const rowShifts = numberValue(row.shifts);
      shifts += rowShifts;
      hours += numberValue(row.hours);
      estimatedAccrued +=
        rowShifts * (rateByEmployee.get(String(row.employee_id)) ?? 0);
    }

    let paidCurrentMonth = 0;
    for (const row of paymentsResult.data ?? []) {
      if (
        Number(row.period_year) === year &&
        Number(row.period_month) === monthIndex + 1
      ) {
        const amount = numberValue(row.amount);
        paidCurrentMonth += row.payment_type === "fine" ? -amount : amount;
      }
    }

    const completedTasks = tasks.filter((row) => row.status === "Выполнено").length;
    const plannedTasks = tasks.filter((row) => row.status !== "Выполнено").length;
    const activeEmployee =
      employees.find((row) => row.is_active === true) ?? employees[0];
    const objectNames = Array.from(
      new Set(
        employees
          .filter((row) => row.is_active === true)
          .map((row) => String(row.object_name ?? "").trim())
          .filter(Boolean),
      ),
    );

    const documents = [
      ...(formsResult.data ?? []).map((row) => ({
        id: row.id,
        source: "onboarding",
        title: String(row.original_name ?? "").trim() || String(row.form_code),
        type: row.form_code,
        status: row.status,
        storage_path: row.storage_path,
        mime_type: row.mime_type,
        updated_at: row.updated_at,
      })),
      ...(legalResult.data ?? []).map((row) => ({
        id: row.id,
        source: "legal",
        title: row.title,
        type: row.document_type,
        status: row.status,
        document_number: row.document_number,
        updated_at: row.updated_at,
      })),
    ];

    return json({
      ok: true,
      month: {
        year,
        month: monthIndex + 1,
        start: monthStart,
        end_exclusive: nextMonthStart,
      },
      profile: {
        full_name: String(activeEmployee.fio ?? profile.full_name ?? "Сотрудник"),
        phone: link.phone_e164,
        profession: String(activeEmployee.position ?? profile.profession ?? ""),
        current_object: String(activeEmployee.object_name ?? profile.object_name ?? ""),
        object_names: objectNames,
        daily_rate: numberValue(activeEmployee.daily_rate),
        avatar_path: String(profile.avatar_path ?? ""),
      },
      summary: {
        shifts,
        hours,
        estimated_accrued: estimatedAccrued,
        paid_current_month: paidCurrentMonth,
        planned_tasks: plannedTasks,
        completed_tasks: completedTasks,
        documents: documents.length,
      },
      tasks,
      payments: paymentsResult.data ?? [],
      documents,
    });
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message || "Не удалось загрузить личный кабинет" }, 500);
  }
});
