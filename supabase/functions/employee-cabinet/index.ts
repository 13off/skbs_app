import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

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

function integerValue(value: unknown) {
  const result = Math.trunc(numberValue(value));
  return Number.isFinite(result) ? result : 0;
}

function cleanText(value: unknown) {
  return String(value ?? "").trim();
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

    let input: Record<string, unknown> = {};
    try {
      const parsed = await request.json();
      if (parsed && typeof parsed === "object") {
        input = parsed as Record<string, unknown>;
      }
    } catch {
      input = {};
    }

    const now = new Date();
    const requestedYear = integerValue(input.year);
    const requestedMonth = integerValue(input.month);
    const requestedEmployeeId = cleanText(input.employee_id);
    const year = requestedYear >= 2020 && requestedYear <= 2100
      ? requestedYear
      : now.getUTCFullYear();
    const month = requestedMonth >= 1 && requestedMonth <= 12
      ? requestedMonth
      : now.getUTCMonth() + 1;
    const monthIndex = month - 1;
    const monthStart = isoDate(year, monthIndex, 1);
    const nextMonthStart = isoDate(year, monthIndex + 1, 1);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: profile, error: profileError } = await adminClient
      .from("user_profiles")
      .select(
        "id, full_name, phone, role, profession, object_name, active_company_id, is_active, avatar_path",
      )
      .eq("id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || !profile.active_company_id) {
      return json(
        { error: "Личный кабинет недоступен. Обратитесь к руководителю" },
        403,
      );
    }

    const profileRole = cleanText(profile.role);
    const isEmployee = profileRole === "employee";
    const isManagerPreview = profileRole === "admin" || profileRole === "developer";
    if (!isEmployee && !isManagerPreview) {
      return json({ error: "Нет доступа к кабинету сотрудника" }, 403);
    }

    let employees: Record<string, unknown>[] = [];
    let contactPhone = cleanText(profile.phone);
    let avatarPath = cleanText(profile.avatar_path);

    if (isEmployee) {
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

      const { data: employeeRows, error: employeesError } = await adminClient
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
      employees = (employeeRows ?? []) as Record<string, unknown>[];
      contactPhone = cleanText(link.phone_e164) || contactPhone;
    } else {
      const baseCandidates = adminClient
        .from("employees")
        .select(
          "id, object_id, object_name, fio, position, phone, daily_rate, is_active, archived_at, updated_at",
        )
        .eq("company_id", profile.active_company_id)
        .eq("is_active", true)
        .is("archived_at", null);
      const candidateRequest = requestedEmployeeId
        ? baseCandidates.eq("id", requestedEmployeeId)
        : baseCandidates;
      const { data: candidateRows, error: candidateError } = await candidateRequest
        .order("fio", { ascending: true });
      if (candidateError) throw candidateError;
      const candidates = (candidateRows ?? []) as Record<string, unknown>[];
      if (candidates.length === 0) {
        return json({ error: "Активный сотрудник для просмотра не найден" }, 404);
      }

      let selectedEmployee = candidates[0];
      if (!requestedEmployeeId && candidates.length > 0) {
        const candidateIds = candidates.map((row) => cleanText(row.id)).filter(Boolean);
        const { data: recentAssignments, error: assignmentError } = await adminClient
          .from("task_assignees")
          .select("employee_id, created_at")
          .in("employee_id", candidateIds)
          .order("created_at", { ascending: false })
          .limit(100);
        if (assignmentError) throw assignmentError;
        const selectedEmployeeId = cleanText(recentAssignments?.[0]?.employee_id);
        const recentEmployee = candidates.find(
          (row) => cleanText(row.id) === selectedEmployeeId,
        );
        if (recentEmployee) selectedEmployee = recentEmployee;
      }

      employees = [selectedEmployee];
      contactPhone = cleanText(selectedEmployee.phone) || contactPhone;
      avatarPath = "";
    }

    if (employees.length === 0) {
      return json({ error: "Рабочая карточка сотрудника не найдена" }, 404);
    }

    const employeeIds = employees.map((row) => cleanText(row.id)).filter(Boolean);
    const rateByEmployee = new Map<string, number>();
    const objectByEmployee = new Map<string, string>();
    for (const row of employees) {
      const employeeId = cleanText(row.id);
      rateByEmployee.set(employeeId, numberValue(row.daily_rate));
      objectByEmployee.set(employeeId, cleanText(row.object_name));
    }

    const [attendanceResult, paymentsResult, assigneesResult, formsResult, legalResult] =
      await Promise.all([
        adminClient
          .from("attendance")
          .select("id, employee_id, work_date, status, shifts, hours")
          .in("employee_id", employeeIds)
          .is("deleted_at", null)
          .gte("work_date", monthStart)
          .lt("work_date", nextMonthStart)
          .order("work_date", { ascending: true }),
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
      new Set((assigneesResult.data ?? []).map((row) => cleanText(row.task_id))),
    ).filter(Boolean);
    let tasks: Record<string, unknown>[] = [];
    if (taskIds.length > 0) {
      const { data, error } = await adminClient
        .from("tasks")
        .select(
          "id, task_date, object_name, axes, work, status, not_done_comment, photo_requirements_enforced, updated_at",
        )
        .in("id", taskIds)
        .eq("is_draft", false)
        .is("deleted_at", null)
        .order("task_date", { ascending: false })
        .order("updated_at", { ascending: false })
        .limit(50);
      if (error) throw error;
      tasks = (data ?? []) as Record<string, unknown>[];

      const visibleTaskIds = tasks.map((row) => cleanText(row.id)).filter(Boolean);
      if (visibleTaskIds.length > 0) {
        const { data: photoRows, error: photoError } = await adminClient
          .from("task_photos")
          .select(
            "id, task_id, storage_path, original_name, photo_stage, created_at",
          )
          .in("task_id", visibleTaskIds)
          .order("created_at", { ascending: false });
        if (photoError) throw photoError;

        const storagePaths = Array.from(
          new Set(
            (photoRows ?? [])
              .map((row) => cleanText(row.storage_path))
              .filter(Boolean),
          ),
        );
        const signedUrlByPath = new Map<string, string>();
        if (storagePaths.length > 0) {
          const { data: signedRows, error: signedError } = await adminClient.storage
            .from("task-photos")
            .createSignedUrls(storagePaths, 60 * 10);
          if (!signedError) {
            for (const row of signedRows ?? []) {
              const path = cleanText(row.path);
              const signedUrl = cleanText(row.signedUrl);
              if (path && signedUrl) signedUrlByPath.set(path, signedUrl);
            }
          }
        }

        const photosByTask = new Map<string, Record<string, unknown>[]>();
        for (const row of photoRows ?? []) {
          const taskId = cleanText(row.task_id);
          const storagePath = cleanText(row.storage_path);
          if (!taskId) continue;
          const list = photosByTask.get(taskId) ?? [];
          list.push({
            id: row.id,
            original_name: row.original_name,
            photo_stage: row.photo_stage,
            created_at: row.created_at,
            signed_url: signedUrlByPath.get(storagePath) ?? "",
          });
          photosByTask.set(taskId, list);
        }

        tasks = tasks.map((row) => ({
          ...row,
          photos: photosByTask.get(cleanText(row.id)) ?? [],
        }));
      }
    }

    const attendance = (attendanceResult.data ?? []).map((row) => {
      const employeeId = cleanText(row.employee_id);
      const rowShifts = numberValue(row.shifts);
      const dailyRate = rateByEmployee.get(employeeId) ?? 0;
      return {
        id: row.id,
        employee_id: employeeId,
        work_date: row.work_date,
        status: row.status,
        shifts: rowShifts,
        hours: numberValue(row.hours),
        object_name: objectByEmployee.get(employeeId) ?? "",
        daily_rate: dailyRate,
        estimated_amount: rowShifts * dailyRate,
      };
    });

    let shifts = 0;
    let hours = 0;
    let estimatedAccrued = 0;
    for (const row of attendance) {
      shifts += numberValue(row.shifts);
      hours += numberValue(row.hours);
      estimatedAccrued += numberValue(row.estimated_amount);
    }

    let paidCurrentMonth = 0;
    for (const row of paymentsResult.data ?? []) {
      if (
        Number(row.period_year) === year &&
        Number(row.period_month) === month
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
          .map((row) => cleanText(row.object_name))
          .filter(Boolean),
      ),
    );

    const documents = [
      ...(formsResult.data ?? []).map((row) => ({
        id: row.id,
        source: "onboarding",
        title: cleanText(row.original_name) || cleanText(row.form_code),
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
        month,
        start: monthStart,
        end_exclusive: nextMonthStart,
      },
      profile: {
        full_name: cleanText(activeEmployee.fio) || cleanText(profile.full_name) || "Сотрудник",
        phone: contactPhone,
        profession: cleanText(activeEmployee.position) || cleanText(profile.profession),
        current_object: cleanText(activeEmployee.object_name) || cleanText(profile.object_name),
        object_names: objectNames,
        daily_rate: numberValue(activeEmployee.daily_rate),
        avatar_path: avatarPath,
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
      attendance,
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
