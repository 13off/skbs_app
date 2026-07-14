import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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

function normalizeSearch(value: unknown) {
  return cleanText(value, 4000)
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/[^а-яa-z0-9-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function searchTokens(value: unknown) {
  return normalizeSearch(value)
    .split(" ")
    .filter((token) => token.length >= 4);
}

function formatDateRu(value: unknown) {
  const date = cleanText(value, 10);
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!match) return date;
  return `${match[3]}.${match[2]}.${match[1]}`;
}

function employeeMatchScore(promptTokens: string[], employee: any) {
  const nameTokens = searchTokens(employee?.fio);
  let score = 0;

  for (let nameIndex = 0; nameIndex < nameTokens.length; nameIndex += 1) {
    const nameToken = nameTokens[nameIndex];
    for (const promptToken of promptTokens) {
      if (promptToken === nameToken) {
        score += nameIndex === 0 ? 8 : 5;
        continue;
      }

      const comparableLength = Math.min(promptToken.length, nameToken.length);
      if (
        comparableLength >= 5 &&
        (promptToken.startsWith(nameToken) || nameToken.startsWith(promptToken))
      ) {
        score += nameIndex === 0 ? 6 : 3;
      }
    }
  }

  return score;
}

function findEmployeesInPrompt(prompt: string, employees: any[]) {
  const promptTokens = searchTokens(prompt);
  const scored = employees
    .map((employee) => ({
      employee,
      score: employeeMatchScore(promptTokens, employee),
    }))
    .filter((item) => item.score > 0)
    .sort((first, second) => second.score - first.score);

  if (scored.length === 0) return [];
  const bestScore = scored[0].score;
  return scored
    .filter((item) => item.score === bestScore)
    .map((item) => item.employee);
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

function buildEmployeeTimesheetResult({
  employee,
  rows,
  scope,
  todayOnly,
}: {
  employee: any;
  rows: any[];
  scope: Record<string, string>;
  todayOnly: boolean;
}) {
  const fullName = cleanText(employee?.fio, 180) || "Сотрудник";
  const totalShifts = rows.reduce(
    (sum, row) => sum + numberValue(row.shifts),
    0,
  );
  const totalHours = rows.reduce(
    (sum, row) => sum + numberValue(row.hours),
    0,
  );
  const workedRows = rows.filter((row) => numberValue(row.shifts) > 0);
  const firstDate = rows.length > 0 ? cleanText(rows[0].work_date, 10) : "";
  const lastDate = rows.length > 0
    ? cleanText(rows[rows.length - 1].work_date, 10)
    : "";
  const periodText = todayOnly
    ? formatDateRu(scope.date)
    : firstDate && lastDate
    ? `${formatDateRu(firstDate)} — ${formatDateRu(lastDate)}`
    : "весь доступный период";

  const lines = rows.map((row) => {
    const parts = [`${formatDateRu(row.work_date)} — ${numberValue(row.shifts).toFixed(1)} смен`];
    const hours = numberValue(row.hours);
    const status = cleanText(row.status, 100);
    const objectName = cleanText(row.object_name, 180);
    const comment = cleanText(row.comment, 240);

    if (hours > 0) parts.push(`${hours.toFixed(1)} ч`);
    if (status) parts.push(status);
    if (!scope.object_name && objectName) parts.push(objectName);
    if (comment) parts.push(comment);
    return parts.join(" • ");
  });

  const summary = rows.length === 0
    ? `По сотруднику ${fullName} строк табеля за выбранный период не найдено.`
    : [
        `${fullName}`,
        `Период: ${periodText}`,
        "",
        ...lines,
      ].join("\n");

  return {
    ok: true,
    mode: "employee_timesheet",
    title: `Табель: ${fullName}`,
    summary,
    highlights: [
      `Строк табеля: ${rows.length}`,
      `Дней с выходом: ${workedRows.length}`,
      `Сумма смен: ${totalShifts.toFixed(1)}`,
      ifValue(totalHours > 0, `Сумма часов: ${totalHours.toFixed(1)}`),
    ].filter(Boolean),
    warnings: rows.length === 0
      ? ["Проверь написание фамилии, объект и выбранный период."]
      : [],
    next_steps: [
      "Сверь итог с разделом «Табель» перед расчётом выплат.",
    ],
    scope: {
      ...scope,
      date: periodText,
    },
    preliminary: true,
    ai_used: false,
  };
}

function ifValue(condition: boolean, value: string) {
  return condition ? value : "";
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
      `За ${formatDateRu(workDate)} найдено ${employees.length} активных сотрудников. ` +
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
      `Область: ${scope.object_name || "Все доступные объекты"}. ` +
      `На ${formatDateRu(workDate)} в работе ${employees.length} сотрудников, ` +
      `${workedRows.length} отмечены в табеле. ` +
      `Выполнено ${doneTasks.length} из ${tasks.length} задач.`,
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
    `Дата: ${formatDateRu(workDate)}`,
    `Объект: ${scope.object_name || "Все доступные объекты"}`,
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

    let allEmployeesQuery: any = userClient
      .from("employees")
      .select("id, fio, position, object_name, is_active, archived_at")
      .eq("company_id", activeCompanyId)
      .order("fio", { ascending: true });

    if (effectiveObjectName) {
      allEmployeesQuery = allEmployeesQuery.eq(
        "object_name",
        effectiveObjectName,
      );
    }

    const { data: allEmployeesData, error: allEmployeesError } =
      await allEmployeesQuery;
    if (allEmployeesError) throw allEmployeesError;

    const allEmployees = allEmployeesData ?? [];
    const normalizedPrompt = normalizeSearch(prompt);
    const asksTimesheet = /табел|смен|выход/.test(normalizedPrompt);
    const asksToday = /сегодня|сегодняшн|за день/.test(normalizedPrompt);
    const matchedEmployees = asksTimesheet
      ? findEmployeesInPrompt(prompt, allEmployees)
      : [];
    const looksNamed = /(?:^|\s)(?:у|по|для)\s+[а-яa-z-]{4,}/.test(
      normalizedPrompt,
    );

    if (asksTimesheet && matchedEmployees.length > 1) {
      return json({
        ok: true,
        mode: "employee_timesheet",
        title: "Уточни сотрудника",
        summary: "По запросу найдено несколько сотрудников.",
        highlights: matchedEmployees
          .slice(0, 10)
          .map((employee) => cleanText(employee.fio, 180)),
        warnings: ["Напиши фамилию, имя или полное ФИО точнее."],
        next_steps: [],
        scope: {
          object_name: effectiveObjectName || "Все доступные объекты",
          date: asksToday ? formatDateRu(workDate) : "весь период",
        },
        preliminary: true,
        ai_used: false,
      });
    }

    if (asksTimesheet && matchedEmployees.length === 1) {
      const employee = matchedEmployees[0];
      let historyQuery: any = userClient
        .from("attendance")
        .select(
          "work_date, shifts, hours, status, object_name, comment",
        )
        .eq("company_id", activeCompanyId)
        .eq("employee_id", employee.id)
        .order("work_date", { ascending: true });

      if (effectiveObjectName) {
        historyQuery = historyQuery.eq("object_name", effectiveObjectName);
      }
      if (asksToday) {
        historyQuery = historyQuery.eq("work_date", workDate);
      }

      const { data: historyRows, error: historyError } = await historyQuery;
      if (historyError) throw historyError;

      return json(
        buildEmployeeTimesheetResult({
          employee,
          rows: historyRows ?? [],
          scope: {
            object_name: effectiveObjectName || "",
            date: workDate,
          },
          todayOnly: asksToday,
        }),
      );
    }

    if (asksTimesheet && looksNamed && matchedEmployees.length === 0) {
      return json({
        ok: true,
        mode: "employee_timesheet",
        title: "Сотрудник не найден",
        summary:
          "Не удалось сопоставить имя из запроса с сотрудником в доступной компании и выбранном объекте.",
        highlights: [],
        warnings: [
          "Проверь написание фамилии или выбери другой объект на Главной.",
        ],
        next_steps: [
          "Например: «Покажи табель за весь период у Филимонова».",
        ],
        scope: {
          object_name: effectiveObjectName || "Все доступные объекты",
          date: "весь период",
        },
        preliminary: true,
        ai_used: false,
      });
    }

    const employees = allEmployees.filter(
      (employee: any) =>
        employee.is_active === true && !employee.archived_at,
    );

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
      attendanceQuery = attendanceQuery.eq(
        "object_name",
        effectiveObjectName,
      );
      tasksQuery = tasksQuery.eq("object_name", effectiveObjectName);
    }

    const [attendanceResult, tasksResult] = await Promise.all([
      attendanceQuery,
      tasksQuery,
    ]);

    if (attendanceResult.error) throw attendanceResult.error;
    if (tasksResult.error) throw tasksResult.error;

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
    const pendingTasks = tasks.filter(
      (task: any) => task.status !== "Выполнено",
    );
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
      if (asksTimesheet) {
        mode = "timesheet_check";
      } else if (/свод|объект|задач|сотрудник|люд/.test(normalizedPrompt)) {
        mode = "site_summary";
      } else if (/документ|акт|записк|письм|отч[её]т/.test(normalizedPrompt)) {
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
      title: "Уточни рабочий запрос",
      summary:
        "Напиши, какие данные нужно показать: сотрудника, период, табель, задачи или документ.",
      highlights: [
        "Например: «Покажи табель за весь период у Филимонова».",
        "Например: «Собери сводку по объекту за сегодня».",
      ],
      warnings: [
        "Помощник работает только на чтение и не изменяет данные приложения.",
      ],
      next_steps: [],
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
