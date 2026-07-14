import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const allowedModes = new Set([
  "timesheet_check",
  "site_summary",
  "document_draft",
  "chat",
]);

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

function cleanText(value: unknown, maxLength = 4000) {
  return String(value ?? "").trim().slice(0, maxLength);
}

function dateKey(value: unknown) {
  const candidate = cleanText(value, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(candidate)) return candidate;
  return new Date().toISOString().slice(0, 10);
}

function numberValue(value: unknown) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function shortNames(rows: any[], employeeById?: Map<string, any>) {
  return rows
    .slice(0, 10)
    .map((row: any) => {
      const employee = employeeById
        ? employeeById.get(String(row.employee_id))
        : row;
      return cleanText(employee?.fio, 160) || "Сотрудник";
    })
    .join(", ");
}

function buildTimesheetResult({
  workDate,
  scope,
  employees,
  attendance,
  missingEmployees,
  elevatedShifts,
  workedRows,
  totalShifts,
  employeeById,
}: any) {
  const warnings: string[] = [];

  if (missingEmployees.length > 0) {
    const names = shortNames(missingEmployees);
    warnings.push(
      `Нет строк табеля: ${missingEmployees.length}. ${names}${
        missingEmployees.length > 10 ? "…" : ""
      }`,
    );
  }

  if (elevatedShifts.length > 0) {
    const values = elevatedShifts
      .slice(0, 10)
      .map((row: any) => {
        const employee = employeeById.get(String(row.employee_id));
        return `${cleanText(employee?.fio, 160) || "Сотрудник"} — ${numberValue(row.shifts)}`;
      })
      .join(", ");
    warnings.push(`Повышенное количество смен, проверь вручную: ${values}`);
  }

  if (warnings.length === 0) {
    warnings.push("Явных пропусков и повышенных значений не найдено.");
  }

  return {
    ok: true,
    mode: "timesheet_check",
    title: "Проверка табеля завершена",
    summary:
      `За ${workDate} найдено ${employees.length} активных сотрудников. ` +
      `Отмечено ${workedRows.length}, всего ${totalShifts.toFixed(1)} смен.`,
    highlights: [
      `Активных сотрудников: ${employees.length}`,
      `Строк табеля: ${attendance.length}`,
      `Отработали: ${workedRows.length}`,
      `Сумма смен: ${totalShifts.toFixed(1)}`,
    ],
    warnings,
    next_steps: [
      "Сверь предупреждения с прорабом или ответственным за табель.",
      "Исправления вноси вручную в разделе «Табель» после проверки.",
    ],
    scope,
    preliminary: true,
    ai_used: false,
  };
}

function buildSiteSummaryResult({
  workDate,
  scope,
  employees,
  missingEmployees,
  workedRows,
  totalShifts,
  tasks,
  doneTasks,
  pendingTasks,
  blockedTasks,
}: any) {
  const warnings: string[] = [];

  if (missingEmployees.length > 0) {
    warnings.push(`У ${missingEmployees.length} сотрудников нет строки табеля.`);
  }
  if (pendingTasks.length > 0) {
    warnings.push(`Не завершено задач: ${pendingTasks.length}.`);
  }
  if (blockedTasks.length > 0) {
    warnings.push(`Есть комментарии о невыполнении у ${blockedTasks.length} задач.`);
  }
  if (warnings.length === 0) {
    warnings.push("По доступным данным критичных отклонений не найдено.");
  }

  return {
    ok: true,
    mode: "site_summary",
    title: "Рабочая сводка за сегодня",
    summary:
      `Область: ${scope.object_name}. На ${workDate} в работе ${employees.length} сотрудников, ` +
      `${workedRows.length} отмечены в табеле. Выполнено ${doneTasks.length} из ${tasks.length} задач.`,
    highlights: [
      `Активных сотрудников: ${employees.length}`,
      `Отработали по табелю: ${workedRows.length}`,
      `Всего смен: ${totalShifts.toFixed(1)}`,
      `Задачи: ${doneTasks.length} выполнено, ${pendingTasks.length} остаётся`,
    ],
    warnings,
    next_steps: [
      "Проверь незавершённые задачи и комментарии исполнителей.",
      "Перед передачей сводки руководителю сверь цифры с первичными данными.",
    ],
    scope,
    preliminary: true,
    ai_used: false,
  };
}

function buildDocumentDraft(prompt: string, scope: any, workDate: string) {
  const subject = prompt || "Рабочая ситуация на объекте";
  const draft = [
    "ЧЕРНОВИК — ТРЕБУЕТ ПРОВЕРКИ",
    "",
    `Дата: ${workDate}`,
    `Объект: ${scope.object_name}`,
    `Тема: ${subject}`,
    "",
    "Фактическая часть:",
    "[Указать подтверждённые обстоятельства, даты, объёмы и ответственных лиц.]",
    "",
    "Результат / текущее состояние:",
    "[Указать фактически достигнутый результат или зафиксированную проблему.]",
    "",
    "Необходимые действия:",
    "[Указать действие, срок и ответственного после согласования.]",
  ].join("\n");

  return {
    ok: true,
    mode: "document_draft",
    title: "Черновик рабочего документа",
    summary: draft,
    highlights: [
      "Добавлена нейтральная структура без выдуманных фактов.",
      "Объект и дата подставлены из текущего рабочего контекста.",
    ],
    warnings: [
      "Заполни все поля в квадратных скобках подтверждёнными данными.",
      "Перед подписанием проверь формулировки, суммы, даты и ответственных.",
    ],
    next_steps: [
      "Уточни тип документа: акт, служебная записка, письмо или отчёт.",
      "После проверки перенеси согласованный текст в нужный шаблон.",
    ],
    scope,
    preliminary: true,
    ai_used: false,
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
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const authorization = request.headers.get("Authorization") ?? "";

    if (!supabaseUrl || !anonKey || !authorization) {
      return json({ error: "Сервис ИИ-помощника не настроен" }, 500);
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

    const input = await request.json().catch(() => ({}));
    let mode = cleanText(input.mode, 40) || "chat";
    const requestedCompanyId = cleanText(input.company_id, 80);
    const requestedObjectName = cleanText(input.object_name, 180);
    const prompt = cleanText(input.prompt, 4000);
    const workDate = dateKey(input.date);

    if (!allowedModes.has(mode)) {
      return json({ error: "Неподдерживаемый режим помощника" }, 400);
    }

    const { data: profile, error: profileError } = await userClient
      .from("user_profiles")
      .select("id, role, object_name, active_company_id, is_active")
      .eq("id", user.id)
      .maybeSingle();

    if (profileError) throw profileError;
    if (!profile || profile.is_active !== true) {
      return json({ error: "Профиль пользователя недоступен" }, 403);
    }

    const activeCompanyId = cleanText(profile.active_company_id, 80);
    if (!activeCompanyId || activeCompanyId !== requestedCompanyId) {
      return json({ error: "Помощник работает только с активной компанией" }, 403);
    }

    const { data: membership, error: membershipError } = await userClient
      .from("company_memberships")
      .select("role, is_active")
      .eq("company_id", activeCompanyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();

    if (membershipError) throw membershipError;
    if (!membership) {
      return json({ error: "Нет доступа к выбранной компании" }, 403);
    }

    const role = cleanText(profile.role, 30) === "admin" ? "admin" : "foreman";
    const assignedObjectName = cleanText(profile.object_name, 180);
    const effectiveObjectName = role === "foreman"
      ? assignedObjectName
      : requestedObjectName;

    if (role === "foreman" && !effectiveObjectName) {
      return json({ error: "Прорабу не назначен объект" }, 403);
    }

    if (effectiveObjectName) {
      const { data: object, error: objectError } = await userClient
        .from("objects")
        .select("id, name")
        .eq("company_id", activeCompanyId)
        .eq("name", effectiveObjectName)
        .eq("is_active", true)
        .maybeSingle();

      if (objectError) throw objectError;
      if (!object) {
        return json({ error: "Объект недоступен в активной компании" }, 403);
      }
    }

    let employeesQuery: any = userClient
      .from("employees")
      .select("id, fio, position, object_name")
      .eq("company_id", activeCompanyId)
      .eq("is_active", true)
      .is("archived_at", null)
      .order("fio", { ascending: true });
    let attendanceQuery: any = userClient
      .from("attendance")
      .select("employee_id, shifts, status, object_name")
      .eq("company_id", activeCompanyId)
      .eq("work_date", workDate);
    let tasksQuery: any = userClient
      .from("tasks")
      .select("id, status, work, axes, not_done_comment, object_name")
      .eq("company_id", activeCompanyId)
      .eq("task_date", workDate)
      .order("created_at", { ascending: true });

    if (effectiveObjectName) {
      employeesQuery = employeesQuery.eq("object_name", effectiveObjectName);
      attendanceQuery = attendanceQuery.eq("object_name", effectiveObjectName);
      tasksQuery = tasksQuery.eq("object_name", effectiveObjectName);
    }

    const [employeesResult, attendanceResult, tasksResult] = await Promise.all([
      employeesQuery,
      attendanceQuery,
      tasksQuery,
    ]);

    if (employeesResult.error) throw employeesResult.error;
    if (attendanceResult.error) throw attendanceResult.error;
    if (tasksResult.error) throw tasksResult.error;

    const employees = employeesResult.data ?? [];
    const attendance = attendanceResult.data ?? [];
    const tasks = tasksResult.data ?? [];
    const employeeById = new Map(
      employees.map((employee: any) => [String(employee.id), employee]),
    );
    const attendanceByEmployeeId = new Map(
      attendance.map((row: any) => [String(row.employee_id), row]),
    );
    const missingEmployees = employees.filter(
      (employee: any) => !attendanceByEmployeeId.has(String(employee.id)),
    );
    const elevatedShifts = attendance.filter(
      (row: any) => numberValue(row.shifts) > 2,
    );
    const workedRows = attendance.filter(
      (row: any) => numberValue(row.shifts) > 0,
    );
    const totalShifts = workedRows.reduce(
      (sum: number, row: any) => sum + numberValue(row.shifts),
      0,
    );
    const doneTasks = tasks.filter((task: any) => task.status === "Выполнено");
    const pendingTasks = tasks.filter((task: any) => task.status !== "Выполнено");
    const blockedTasks = tasks.filter(
      (task: any) => cleanText(task.not_done_comment, 500).length > 0,
    );
    const scope = {
      object_name: effectiveObjectName || "Все доступные объекты",
      date: workDate,
    };
    const context = {
      workDate,
      scope,
      employees,
      attendance,
      missingEmployees,
      elevatedShifts,
      workedRows,
      totalShifts,
      employeeById,
      tasks,
      doneTasks,
      pendingTasks,
      blockedTasks,
    };

    if (mode === "chat") {
      const normalized = prompt.toLowerCase();
      if (/табел|смен|выход/.test(normalized)) {
        mode = "timesheet_check";
      } else if (/свод|объект|задач|сотрудник|люд/.test(normalized)) {
        mode = "site_summary";
      } else if (/документ|акт|записк|письм|отч[её]т/.test(normalized)) {
        mode = "document_draft";
      }
    }

    if (mode === "timesheet_check") {
      return json(buildTimesheetResult(context));
    }
    if (mode === "site_summary") {
      return json(buildSiteSummaryResult(context));
    }
    if (mode === "document_draft") {
      return json(buildDocumentDraft(prompt, scope, workDate));
    }

    return json({
      ok: true,
      mode: "chat",
      title: "Что умеет помощник сейчас",
      summary:
        "Напиши запрос про табель, рабочую сводку, сотрудников, задачи или черновик документа. Помощник определит нужный сценарий и покажет предварительный результат.",
      highlights: [
        "Проверка пропусков и повышенных значений в табеле.",
        "Сводка по людям, сменам и задачам текущего объекта.",
        "Безопасный черновик документа без выдуманных фактов.",
      ],
      warnings: [
        "Помощник работает только на чтение и не изменяет данные приложения.",
      ],
      next_steps: [
        "Сформулируй запрос конкретнее или выбери быстрое действие сверху.",
      ],
      scope,
      preliminary: true,
      ai_used: false,
    });
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
