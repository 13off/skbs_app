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

function clean(value: unknown, max = 4000) {
  return String(value ?? "").trim().slice(0, max);
}

function normalize(value: unknown) {
  return clean(value)
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/\s+/g, " ")
    .trim();
}

function numberValue(value: unknown) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function dateKey(value: unknown) {
  const candidate = clean(value, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(candidate)) return candidate;
  return new Date().toISOString().slice(0, 10);
}

function parseDate(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return new Date();
  return new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
}

function isoDate(value: Date) {
  return `${value.getUTCFullYear()}-${String(value.getUTCMonth() + 1).padStart(2, "0")}-${String(value.getUTCDate()).padStart(2, "0")}`;
}

function addDays(value: string, days: number) {
  const date = parseDate(value);
  date.setUTCDate(date.getUTCDate() + days);
  return isoDate(date);
}

function monthRange(value: string) {
  const date = parseDate(value);
  const first = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1));
  const last = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0));
  return { start: isoDate(first), end: isoDate(last) };
}

function dateRu(value: unknown) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(clean(value, 10));
  return match ? `${match[3]}.${match[2]}.${match[1]}` : clean(value, 20);
}

function money(value: unknown) {
  return `${Math.round(numberValue(value)).toLocaleString("ru-RU")} ₽`;
}

function shortList(values: string[], limit = 12) {
  const shown = values.slice(0, limit);
  return `${shown.join(", ")}${values.length > limit ? "…" : ""}`;
}

function detectInsight(prompt: string) {
  const text = normalize(prompt);
  if (
    /(кому|у кого|кто).*(не выплат|не доплат|должн|долг|остаток|задолж)/.test(text) ||
    /(долг|задолж|остаток).*(выплат|зарплат|сотрудник)/.test(text)
  ) {
    return "unpaid_employees";
  }
  if (
    /(документ|договор|удостоверен|медосмотр|патент).*(заканч|истека|просроч|срок)/.test(text) ||
    /(заканч|истека|просроч).*(документ|договор|удостоверен|медосмотр|патент)/.test(text)
  ) {
    return "expiring_documents";
  }
  if (
    /(сводк|отчет|отчёт|итог).*(недел|7 дн)/.test(text) ||
    /(недел|7 дн).*(сводк|отчет|отчёт|итог)/.test(text)
  ) {
    return "weekly_site_report";
  }
  if (
    /(кто|кого|сотрудник).*(не выш|не явил|отсутств|нет на работ)/.test(text) ||
    /(не выш|не явил|отсутств).*(сотрудник|сегодня|объект)/.test(text)
  ) {
    return "absence_today";
  }
  return "unknown";
}

async function hasPermission(client: any, code: string) {
  const { data, error } = await client.rpc("current_user_has_permission", {
    p_permission_code: code,
  });
  if (error) throw error;
  return data === true;
}

function baseResult({
  mode,
  title,
  summary,
  highlights = [],
  warnings = [],
  nextSteps = [],
  objectName,
  period,
}: {
  mode: string;
  title: string;
  summary: string;
  highlights?: string[];
  warnings?: string[];
  nextSteps?: string[];
  objectName: string;
  period: string;
}) {
  return {
    ok: true,
    mode,
    title,
    summary,
    highlights,
    warnings,
    next_steps: nextSteps,
    scope: {
      object_name: objectName || "Все доступные объекты",
      date: period,
    },
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
    const url = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const authorization = request.headers.get("Authorization") ?? "";
    if (!url || !anonKey || !authorization) {
      return json({ error: "Сервис оперативной аналитики не настроен" }, 500);
    }

    const client = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const {
      data: { user },
      error: userError,
    } = await client.auth.getUser();
    if (userError || !user) {
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const input = await request.json().catch(() => ({}));
    const companyId = clean(input.company_id, 80);
    const requestedObjectName = clean(input.object_name, 180);
    const prompt = clean(input.prompt, 4000);
    const workDate = dateKey(input.date);
    const insight = detectInsight(prompt);

    if (!companyId) return json({ error: "Не выбрана активная компания" }, 400);
    if (!prompt) return json({ error: "Напиши рабочий запрос" }, 400);
    if (insight === "unknown") {
      return json({ error: "Не удалось определить вид оперативной проверки" }, 400);
    }

    const { data: profile, error: profileError } = await client
      .from("user_profiles")
      .select("id, active_company_id, is_active")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.is_active !== true) {
      return json({ error: "Профиль пользователя недоступен" }, 403);
    }
    if (clean(profile.active_company_id, 80) !== companyId) {
      return json({ error: "Аналитика работает только с активной компанией" }, 403);
    }

    const { data: membership, error: membershipError } = await client
      .from("company_memberships")
      .select("role, is_active")
      .eq("company_id", companyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return json({ error: "Нет доступа к компании" }, 403);

    if (!(await hasPermission(client, "ai.use"))) {
      return json({ error: "Роль не имеет доступа к ИИ-помощнику" }, 403);
    }

    let objectName = requestedObjectName;
    if (objectName) {
      const { data: object, error: objectError } = await client
        .from("objects")
        .select("id, name")
        .eq("company_id", companyId)
        .eq("name", objectName)
        .eq("is_active", true)
        .maybeSingle();
      if (objectError) throw objectError;
      if (!object) return json({ error: "Выбранный объект недоступен" }, 403);
      objectName = clean(object.name, 180);
    }

    if (insight === "absence_today") {
      let employeesQuery: any = client
        .from("employees")
        .select("id, fio, position, object_name")
        .eq("company_id", companyId)
        .eq("is_active", true)
        .is("archived_at", null)
        .order("fio");
      let attendanceQuery: any = client
        .from("attendance")
        .select("employee_id, shifts, hours, status, comment, object_name")
        .eq("company_id", companyId)
        .eq("work_date", workDate);
      if (objectName) {
        employeesQuery = employeesQuery.eq("object_name", objectName);
        attendanceQuery = attendanceQuery.eq("object_name", objectName);
      }

      const [employeesResult, attendanceResult] = await Promise.all([
        employeesQuery,
        attendanceQuery,
      ]);
      if (employeesResult.error) throw employeesResult.error;
      if (attendanceResult.error) throw attendanceResult.error;

      const employees = employeesResult.data ?? [];
      const attendance = attendanceResult.data ?? [];
      const attendanceByEmployee = new Map(
        attendance.map((row: any) => [String(row.employee_id), row]),
      );
      const absent = employees.filter((employee: any) => {
        const row = attendanceByEmployee.get(String(employee.id));
        return !row || numberValue(row.shifts) <= 0;
      });
      const present = employees.length - absent.length;
      const absentNames = absent.map((employee: any) => clean(employee.fio, 180));

      return json(baseResult({
        mode: insight,
        title: "Кто не вышел сегодня",
        summary: absent.length === 0
          ? `На ${dateRu(workDate)} у всех ${employees.length} доступных активных сотрудников есть положительная отметка табеля.`
          : `На ${dateRu(workDate)} без положительной отметки табеля: ${absent.length}.\n\n${shortList(absentNames, 30)}`,
        highlights: [
          `Активных сотрудников: ${employees.length}`,
          `С положительной отметкой: ${present}`,
          `Без выхода: ${absent.length}`,
        ],
        warnings: absent.length > 0
          ? ["Отсутствие строки табеля не всегда означает неявку — сверь данные с прорабом."]
          : [],
        nextSteps: absent.length > 0
          ? ["Проверь табель и причины отсутствия перед изменением данных."]
          : [],
        objectName,
        period: dateRu(workDate),
      }));
    }

    if (insight === "unpaid_employees") {
      if (!(await hasPermission(client, "accounting.payments.view"))) {
        return json({ error: "Нет права просматривать выплаты" }, 403);
      }

      const range = monthRange(workDate);
      let employeesQuery: any = client
        .from("employees")
        .select("id, fio, daily_rate, object_name")
        .eq("company_id", companyId)
        .eq("is_active", true)
        .is("archived_at", null)
        .order("fio");
      let attendanceQuery: any = client
        .from("attendance")
        .select("employee_id, shifts, object_name")
        .eq("company_id", companyId)
        .gte("work_date", range.start)
        .lte("work_date", range.end);
      let paymentsQuery: any = client
        .from("payments")
        .select("employee_id, amount, payment_type, object_id")
        .eq("company_id", companyId)
        .gte("payment_date", range.start)
        .lte("payment_date", range.end);
      if (objectName) {
        employeesQuery = employeesQuery.eq("object_name", objectName);
        attendanceQuery = attendanceQuery.eq("object_name", objectName);
      }

      const [employeesResult, attendanceResult, paymentsResult] = await Promise.all([
        employeesQuery,
        attendanceQuery,
        paymentsQuery,
      ]);
      if (employeesResult.error) throw employeesResult.error;
      if (attendanceResult.error) throw attendanceResult.error;
      if (paymentsResult.error) throw paymentsResult.error;

      const employees = employeesResult.data ?? [];
      const attendance = attendanceResult.data ?? [];
      let payments = paymentsResult.data ?? [];
      const employeeIds = new Set(employees.map((employee: any) => String(employee.id)));
      payments = payments.filter((payment: any) => employeeIds.has(String(payment.employee_id)));

      const shiftsByEmployee = new Map<string, number>();
      for (const row of attendance) {
        const id = String(row.employee_id);
        shiftsByEmployee.set(id, (shiftsByEmployee.get(id) ?? 0) + numberValue(row.shifts));
      }
      const paidByEmployee = new Map<string, number>();
      for (const payment of payments) {
        const id = String(payment.employee_id);
        paidByEmployee.set(id, (paidByEmployee.get(id) ?? 0) + numberValue(payment.amount));
      }

      const balances = employees.map((employee: any) => {
        const id = String(employee.id);
        const shifts = shiftsByEmployee.get(id) ?? 0;
        const accrued = shifts * numberValue(employee.daily_rate);
        const paid = paidByEmployee.get(id) ?? 0;
        return {
          name: clean(employee.fio, 180),
          objectName: clean(employee.object_name, 180),
          shifts,
          accrued,
          paid,
          balance: accrued - paid,
        };
      }).filter((row: any) => row.balance > 0.5)
        .sort((a: any, b: any) => b.balance - a.balance);

      const totalDebt = balances.reduce(
        (sum: number, row: any) => sum + row.balance,
        0,
      );
      const lines = balances.slice(0, 30).map((row: any) =>
        `${row.name} — ${money(row.balance)} (${row.shifts.toFixed(1)} смен; начислено ${money(row.accrued)}, выплачено ${money(row.paid)})`
      );

      return json(baseResult({
        mode: insight,
        title: "Кому ещё не выплатили",
        summary: balances.length === 0
          ? `За период ${dateRu(range.start)} — ${dateRu(range.end)} положительных остатков не найдено.`
          : `Положительный расчётный остаток есть у ${balances.length} сотрудников.\n\n${lines.join("\n")}${balances.length > 30 ? "\n…" : ""}`,
        highlights: [
          `Сотрудников с остатком: ${balances.length}`,
          `Общий расчётный остаток: ${money(totalDebt)}`,
          `Период: ${dateRu(range.start)} — ${dateRu(range.end)}`,
        ],
        warnings: [
          "Расчёт предварительный: начисление считается как смены × дневная ставка.",
          "Штрафы, ручные корректировки и договорные особенности проверь в карточке выплат.",
        ],
        nextSteps: balances.length > 0
          ? ["Сверь суммы с бухгалтерией и чеками перед проведением выплаты."]
          : [],
        objectName,
        period: `${dateRu(range.start)} — ${dateRu(range.end)}`,
      }));
    }

    if (insight === "expiring_documents") {
      if (!(await hasPermission(client, "legal.documents.view"))) {
        return json({ error: "Нет права просматривать документы" }, 403);
      }

      const horizon = addDays(workDate, 30);
      let query: any = client
        .from("legal_documents")
        .select("title, document_type, document_number, status, expires_on, object_id, approval_status, next_action")
        .eq("company_id", companyId)
        .is("archived_at", null)
        .not("expires_on", "is", null)
        .lte("expires_on", horizon)
        .order("expires_on", { ascending: true })
        .limit(100);

      if (objectName) {
        const { data: object, error: objectError } = await client
          .from("objects")
          .select("id")
          .eq("company_id", companyId)
          .eq("name", objectName)
          .maybeSingle();
        if (objectError) throw objectError;
        if (object?.id) query = query.eq("object_id", object.id);
      }

      const { data, error } = await query;
      if (error) throw error;
      const documents = data ?? [];
      const expired = documents.filter((document: any) => clean(document.expires_on, 10) < workDate);
      const upcoming = documents.filter((document: any) => clean(document.expires_on, 10) >= workDate);
      const lines = documents.slice(0, 40).map((document: any) => {
        const expiredLabel = clean(document.expires_on, 10) < workDate ? "ПРОСРОЧЕН" : "до";
        return `${clean(document.title, 220) || clean(document.document_type, 160)} — ${expiredLabel} ${dateRu(document.expires_on)}${clean(document.document_number, 100) ? ` • № ${clean(document.document_number, 100)}` : ""}`;
      });

      return json(baseResult({
        mode: insight,
        title: "Сроки документов",
        summary: documents.length === 0
          ? `Просроченных или заканчивающихся до ${dateRu(horizon)} документов не найдено.`
          : `Найдено документов: ${documents.length}.\n\n${lines.join("\n")}${documents.length > 40 ? "\n…" : ""}`,
        highlights: [
          `Просрочено: ${expired.length}`,
          `Заканчивается в течение 30 дней: ${upcoming.length}`,
          `Проверено до: ${dateRu(horizon)}`,
        ],
        warnings: expired.length > 0
          ? ["Есть просроченные документы — проверь возможность допуска сотрудников и выполнения работ."]
          : [],
        nextSteps: documents.length > 0
          ? ["Назначь ответственного и срок обновления документа."]
          : [],
        objectName,
        period: `${dateRu(workDate)} — ${dateRu(horizon)}`,
      }));
    }

    const periodStart = addDays(workDate, -6);
    let employeesQuery: any = client
      .from("employees")
      .select("id, fio, object_name")
      .eq("company_id", companyId)
      .eq("is_active", true)
      .is("archived_at", null);
    let attendanceQuery: any = client
      .from("attendance")
      .select("employee_id, work_date, shifts, hours, status, object_name")
      .eq("company_id", companyId)
      .gte("work_date", periodStart)
      .lte("work_date", workDate);
    let tasksQuery: any = client
      .from("tasks")
      .select("id, task_date, status, work, not_done_comment, object_name")
      .eq("company_id", companyId)
      .gte("task_date", periodStart)
      .lte("task_date", workDate);
    if (objectName) {
      employeesQuery = employeesQuery.eq("object_name", objectName);
      attendanceQuery = attendanceQuery.eq("object_name", objectName);
      tasksQuery = tasksQuery.eq("object_name", objectName);
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
    const totalShifts = attendance.reduce(
      (sum: number, row: any) => sum + numberValue(row.shifts),
      0,
    );
    const totalHours = attendance.reduce(
      (sum: number, row: any) => sum + numberValue(row.hours),
      0,
    );
    const doneTasks = tasks.filter((task: any) => task.status === "Выполнено");
    const pendingTasks = tasks.filter((task: any) => task.status !== "Выполнено");
    const blockedTasks = tasks.filter(
      (task: any) => clean(task.not_done_comment, 500).length > 0,
    );
    const activeEmployeeDays = new Set(
      attendance
        .filter((row: any) => numberValue(row.shifts) > 0)
        .map((row: any) => `${row.employee_id}:${row.work_date}`),
    ).size;

    return json(baseResult({
      mode: insight,
      title: "Недельная сводка по объекту",
      summary:
        `Период ${dateRu(periodStart)} — ${dateRu(workDate)}. ` +
        `Активных сотрудников в доступной области: ${employees.length}. ` +
        `В табеле ${attendance.length} строк и ${totalShifts.toFixed(1)} смен. ` +
        `Выполнено ${doneTasks.length} из ${tasks.length} задач.`,
      highlights: [
        `Сотруднико-дней с выходом: ${activeEmployeeDays}`,
        `Смен: ${totalShifts.toFixed(1)}`,
        ...(totalHours > 0 ? [`Часов: ${totalHours.toFixed(1)}`] : []),
        `Задачи: ${doneTasks.length} выполнено, ${pendingTasks.length} остаётся`,
      ],
      warnings: [
        ...(pendingTasks.length > 0 ? [`Незавершённых задач: ${pendingTasks.length}.`] : []),
        ...(blockedTasks.length > 0 ? [`С причиной невыполнения: ${blockedTasks.length}.`] : []),
      ],
      nextSteps: pendingTasks.length > 0
        ? ["Открой незавершённые задачи и проверь причины до передачи отчёта."]
        : ["Сверь итоговые цифры перед передачей руководителю."],
      objectName,
      period: `${dateRu(periodStart)} — ${dateRu(workDate)}`,
    }));
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
