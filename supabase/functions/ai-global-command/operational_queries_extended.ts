import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import { clean, nameMatches, normalized } from "./shared.ts";

type EmployeeFinanceRow = {
  id: string;
  fio: string;
  object_name: string;
  daily_rate: number | null;
};

type AttendanceRow = {
  employee_id: string;
  work_date: string;
  shifts: number | string | null;
};

type PaymentRow = {
  employee_id: string;
  amount: number | string | null;
};

type ObjectRow = { name: string };

type LegalMatterRow = {
  id: string;
  title: string;
  risk_level: string;
  status: string;
  due_at: string | null;
  requires_manager_decision: boolean;
  manager_question: string | null;
  decision_status: string | null;
};

type FlightRow = {
  id: string;
  application_id: string;
  departure_at: string;
  arrival_at: string | null;
  origin: string;
  destination: string;
  flight_number: string;
  status: string;
};

type CandidateRow = { id: string; full_name: string };

type MilestoneRow = {
  id: string;
  object_name: string;
  title: string;
  status: string;
  target_date: string;
};

function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

function attendanceRole(role: string) {
  return managerRole(role) || role === "foreman" || role === "accountant";
}

function financeRole(role: string) {
  return managerRole(role) || role === "accountant";
}

function legalRole(role: string) {
  return managerRole(role) || role === "lawyer";
}

function flightRole(role: string) {
  return managerRole(role) || role === "hr";
}

function milestoneRole(role: string) {
  return managerRole(role) || role === "foreman";
}

function asNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const parsed = Number(String(value ?? "").replace(",", "."));
  return Number.isFinite(parsed) ? parsed : 0;
}

function money(value: number): string {
  return `${Math.round(value).toLocaleString("ru-RU")} ₽`;
}

function readResult({
  title,
  summary,
  highlights = [],
  warnings = [],
  objectName = "",
  date,
}: {
  title: string;
  summary: string;
  highlights?: string[];
  warnings?: string[];
  objectName?: string;
  date: string;
}) {
  return {
    ok: true,
    mode: "global_voice",
    title,
    summary,
    highlights,
    warnings,
    next_steps: [],
    scope: {
      object_name: objectName || "Все доступные объекты",
      date,
    },
    preliminary: false,
    ai_used: false,
    action: null,
  };
}

async function activeObjectNames(
  client: SupabaseClient,
  companyId: string,
): Promise<string[]> {
  const { data, error } = await client
    .from("objects")
    .select("name")
    .eq("company_id", companyId)
    .eq("is_active", true)
    .order("name")
    .limit(300);
  if (error) throw error;
  return ((data ?? []) as ObjectRow[])
    .map((item) => clean(item.name, 180))
    .filter(Boolean);
}

async function resolveObjectName({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
}): Promise<string> {
  if (role === "foreman") return assignedObject;
  if (requestedObject) return requestedObject;
  const names = await activeObjectNames(client, companyId);
  const matches = names.filter((name) => nameMatches(prompt, name));
  return matches.length === 1 ? matches[0] : "";
}

function dateParts(date: string) {
  const match = date.match(/^(20\d{2})-(\d{2})-(\d{2})$/);
  return {
    year: Number(match?.[1] ?? new Date().getUTCFullYear()),
    month: Number(match?.[2] ?? new Date().getUTCMonth() + 1),
    day: Number(match?.[3] ?? 1),
  };
}

const monthWords: Array<[RegExp, number]> = [
  [/январ/, 1],
  [/феврал/, 2],
  [/март/, 3],
  [/апрел/, 4],
  [/\bма[йяею]\b|\bмай\b/, 5],
  [/июн/, 6],
  [/июл/, 7],
  [/август/, 8],
  [/сентябр/, 9],
  [/октябр/, 10],
  [/ноябр/, 11],
  [/декабр/, 12],
];

function requestedMonth(prompt: string, date: string) {
  const value = normalized(prompt);
  const base = dateParts(date);
  let year = base.year;
  let month = base.month;

  const explicitYear = value.match(/\b(20\d{2})\b/);
  if (explicitYear) year = Number(explicitYear[1]);

  for (const [pattern, number] of monthWords) {
    if (!pattern.test(value)) continue;
    month = number;
    if (!explicitYear && month > base.month + 1) year -= 1;
    return { year, month };
  }

  if (/(?:прошл\w*\s+месяц|за\s+прошлый)/.test(value)) {
    month -= 1;
    if (month < 1) {
      month = 12;
      year -= 1;
    }
  }
  return { year, month };
}

function monthBounds(year: number, month: number) {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return {
    start: `${year}-${String(month).padStart(2, "0")}-01`,
    end: `${year}-${String(month).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`,
  };
}

const monthTitles = [
  "", "январь", "февраль", "март", "апрель", "май", "июнь", "июль",
  "август", "сентябрь", "октябрь", "ноябрь", "декабрь",
];

function attendanceIntent(value: string) {
  return /(?:кто|сколько|кого).*(?:не\s+выш|выш|на\s+работ|отработ|в\s+табел|на\s+объект)|(?:не\s+выш|вышел|вышли|отсутств).*(?:сотруд|работник|сегодня|вчера|объект)/.test(
    value,
  );
}

function financeIntent(value: string) {
  return /(?:сколько|кому|кто|что\s+по).*(?:начисл|выплач|остат|должн|долг|зарплат|выплат|переплат)|(?:кому\s+должны|кто\s+не\s+получил)/.test(
    value,
  );
}

function legalReadIntent(value: string) {
  return /(?:какие|сколько|что\s+по|что).*(?:юрид|риск|решен\w*\s+руковод|жд[её]т\s+решен)|(?:высок|критич|просроч).*(?:юрид|риск|вопрос)/.test(
    value,
  );
}

function flightReadIntent(value: string) {
  return /(?:кто|какие|сколько).*(?:вылет|прилет|рейс|летит)|(?:кто\s+сегодня\s+летит)/.test(
    value,
  );
}

function milestoneReadIntent(value: string) {
  return /(?:что\s+по|какие|сколько|что).*(?:цел|этап).*(?:просроч|открыт|в\s+работ|сегодня|готов)|(?:что\s+просрочено).*(?:цел|этап)/.test(
    value,
  );
}

export function extendedOperationalQueryIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return attendanceIntent(value) ||
    financeIntent(value) ||
    legalReadIntent(value) ||
    flightReadIntent(value) ||
    milestoneReadIntent(value);
}

async function attendanceSummary({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
  date: string;
}) {
  if (!attendanceRole(role)) {
    return { error: "Сводка по явке недоступна текущей роли", status: 403 };
  }
  const objectName = await resolveObjectName({
    client,
    companyId,
    role,
    assignedObject,
    requestedObject,
    prompt,
  });

  let employeesQuery = client
    .from("employees")
    .select("id, fio, object_name, daily_rate")
    .eq("company_id", companyId)
    .eq("is_active", true)
    .is("archived_at", null)
    .order("fio")
    .limit(1000);
  if (objectName) employeesQuery = employeesQuery.eq("object_name", objectName);
  const { data: employeeData, error: employeeError } = await employeesQuery;
  if (employeeError) throw employeeError;
  const employees = (employeeData ?? []) as EmployeeFinanceRow[];
  const employeeIds = employees.map((item) => item.id).filter(Boolean);

  const attendanceResponse = employeeIds.length === 0
    ? { data: [] as unknown[], error: null }
    : await client.rpc("get_attendance_rows_fast", {
      p_start_date: date,
      p_end_date: date,
      p_object_name: objectName || null,
      p_employee_ids: employeeIds,
      p_worked_only: false,
    });
  if (attendanceResponse.error) throw attendanceResponse.error;
  const rows = (attendanceResponse.data ?? []) as AttendanceRow[];
  const shifts = new Map<string, number>();
  for (const row of rows) {
    shifts.set(clean(row.employee_id, 80), asNumber(row.shifts));
  }

  const worked = employees.filter((item) => (shifts.get(item.id) ?? 0) > 0);
  const unmarked = employees.filter((item) => (shifts.get(item.id) ?? 0) <= 0);
  const value = normalized(prompt);
  const wantsMissing = /(?:не\s+выш|отсутств|не\s+отмеч|кого\s+нет)/.test(value);
  const wantsList = /(?:кто|кого)/.test(value);
  const selected = wantsMissing ? unmarked : worked;
  const label = wantsMissing ? "без положительной отметки" : "с положительной сменой";
  const highlights = wantsList
    ? selected.slice(0, 30).map((item) => {
      const amount = shifts.get(item.id) ?? 0;
      return wantsMissing ? item.fio : `${item.fio} — ${amount} смены`;
    })
    : [];

  return {
    body: readResult({
      title: wantsMissing ? "Не отмечены в табеле" : "Явка по табелю",
      summary: `${objectName ? `${objectName}: ` : ""}${selected.length} из ${employees.length} сотрудников ${label} на ${date}.`,
      highlights,
      warnings: wantsMissing
        ? [
          "Это данные табеля: сотрудник без положительной смены может быть ещё не отмечен, а не обязательно отсутствовать фактически.",
          ifMore(selected.length, highlights.length),
        ].filter(Boolean)
        : [ifMore(selected.length, highlights.length)].filter(Boolean),
      objectName,
      date,
    }),
    status: 200,
  };
}

function ifMore(total: number, shown: number) {
  return shown > 0 && total > shown ? `Показаны первые ${shown} из ${total}.` : "";
}

async function financeSummary({
  client,
  companyId,
  role,
  requestedObject,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  requestedObject: string;
  prompt: string;
  date: string;
}) {
  if (!financeRole(role)) {
    return { error: "Финансовая сводка недоступна текущей роли", status: 403 };
  }
  const objectName = await resolveObjectName({
    client,
    companyId,
    role,
    assignedObject: "",
    requestedObject,
    prompt,
  });
  const period = requestedMonth(prompt, date);
  const bounds = monthBounds(period.year, period.month);

  let employeesQuery = client
    .from("employees")
    .select("id, fio, object_name, daily_rate")
    .eq("company_id", companyId)
    .is("archived_at", null)
    .order("fio")
    .limit(1000);
  if (objectName) employeesQuery = employeesQuery.eq("object_name", objectName);
  const { data: employeeData, error: employeeError } = await employeesQuery;
  if (employeeError) throw employeeError;
  const employees = (employeeData ?? []) as EmployeeFinanceRow[];
  const employeeIds = employees.map((item) => item.id).filter(Boolean);

  const [attendanceResponse, paymentResponse] = employeeIds.length === 0
    ? [
      { data: [] as unknown[], error: null },
      { data: [] as unknown[], error: null },
    ]
    : await Promise.all([
      client.rpc("get_attendance_rows_fast", {
        p_start_date: bounds.start,
        p_end_date: bounds.end,
        p_object_name: objectName || null,
        p_employee_ids: employeeIds,
        p_worked_only: false,
      }),
      client
        .from("payments")
        .select("employee_id, amount")
        .in("employee_id", employeeIds)
        .eq("period_year", period.year)
        .eq("period_month", period.month),
    ]);
  if (attendanceResponse.error) throw attendanceResponse.error;
  if (paymentResponse.error) throw paymentResponse.error;

  const shifts = new Map<string, number>();
  for (const row of (attendanceResponse.data ?? []) as AttendanceRow[]) {
    const id = clean(row.employee_id, 80);
    shifts.set(id, (shifts.get(id) ?? 0) + asNumber(row.shifts));
  }
  const paid = new Map<string, number>();
  for (const row of (paymentResponse.data ?? []) as PaymentRow[]) {
    const id = clean(row.employee_id, 80);
    paid.set(id, (paid.get(id) ?? 0) + asNumber(row.amount));
  }

  const balances = employees.map((employee) => {
    const employeeShifts = shifts.get(employee.id) ?? 0;
    const accrued = employeeShifts * asNumber(employee.daily_rate);
    const employeePaid = paid.get(employee.id) ?? 0;
    return {
      employee,
      shifts: employeeShifts,
      accrued,
      paid: employeePaid,
      balance: accrued - employeePaid,
    };
  });
  const totalAccrued = balances.reduce((sum, item) => sum + item.accrued, 0);
  const totalPaid = balances.reduce((sum, item) => sum + item.paid, 0);
  const totalBalance = totalAccrued - totalPaid;
  const value = normalized(prompt);
  const wantsDebtors = /(?:кому\s+должны|кто\s+не\s+получил|кому.*остат)/.test(value);
  const wantsOverpaid = /переплат/.test(value);
  const selected = wantsOverpaid
    ? balances.filter((item) => item.balance < -0.5).sort((a, b) => a.balance - b.balance)
    : balances.filter((item) => item.balance > 0.5).sort((a, b) => b.balance - a.balance);
  const highlights = wantsDebtors || wantsOverpaid
    ? selected.slice(0, 25).map((item) =>
      `${item.employee.fio}: ${wantsOverpaid ? "переплата" : "остаток"} ${money(Math.abs(item.balance))} · ${item.shifts} смены`
    )
    : [
      `Начислено: ${money(totalAccrued)}`,
      `Выплачено: ${money(totalPaid)}`,
      `${totalBalance >= 0 ? "Осталось выплатить" : "Переплата"}: ${money(Math.abs(totalBalance))}`,
    ];

  return {
    body: readResult({
      title: "Финансовая сводка",
      summary: `${monthTitles[period.month]} ${period.year}${objectName ? ` · ${objectName}` : ""}: начислено ${money(totalAccrued)}, выплачено ${money(totalPaid)}, ${totalBalance >= 0 ? "остаток" : "переплата"} ${money(Math.abs(totalBalance))}.`,
      highlights,
      warnings: [ifMore(selected.length, highlights.length)].filter(Boolean),
      objectName,
      date,
    }),
    status: 200,
  };
}

async function legalSummary({
  client,
  companyId,
  role,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  prompt: string;
  date: string;
}) {
  if (!legalRole(role)) {
    return { error: "Юридическая сводка недоступна текущей роли", status: 403 };
  }
  const { data, error } = await client
    .from("legal_matters")
    .select(
      "id, title, risk_level, status, due_at, requires_manager_decision, manager_question, decision_status",
    )
    .eq("company_id", companyId)
    .order("updated_at", { ascending: false })
    .limit(500);
  if (error) throw error;
  const matters = (data ?? []) as LegalMatterRow[];
  const value = normalized(prompt);
  const pending = matters.filter(
    (item) => item.requires_manager_decision && clean(item.decision_status, 30) === "pending",
  );
  const highRisk = matters.filter(
    (item) =>
      (item.risk_level === "high" || item.risk_level === "critical") &&
      item.status !== "resolved" &&
      item.status !== "closed",
  );
  const overdue = matters.filter((item) => {
    if (!item.due_at || item.status === "resolved" || item.status === "closed") return false;
    return item.due_at.slice(0, 10) < date;
  });

  const wantsPending = /(?:решен|руковод|согласован|ждет|ждёт)/.test(value);
  const wantsOverdue = /просроч/.test(value);
  const selected = wantsPending ? pending : wantsOverdue ? overdue : highRisk;
  const highlights = selected.slice(0, 20).map((item) => {
    const risk = item.risk_level === "critical" ? "критический" : item.risk_level;
    const due = item.due_at ? ` · срок ${item.due_at.slice(0, 10)}` : "";
    return `${item.title} · риск ${risk}${due}`;
  });

  return {
    body: readResult({
      title: wantsPending
        ? "Ждут решения руководителя"
        : wantsOverdue
        ? "Просроченные юридические вопросы"
        : "Юридические риски",
      summary: wantsPending
        ? `Решения руководителя ждут ${pending.length} юридических вопросов.`
        : wantsOverdue
        ? `Просрочено ${overdue.length} открытых юридических вопросов.`
        : `Высокий или критический риск: ${highRisk.length} открытых вопросов.`,
      highlights,
      warnings: [ifMore(selected.length, highlights.length)].filter(Boolean),
      date,
    }),
    status: 200,
  };
}

async function flightSummary({
  client,
  companyId,
  role,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  prompt: string;
  date: string;
}) {
  if (!flightRole(role)) {
    return { error: "Сводка по рейсам недоступна текущей роли", status: 403 };
  }
  const start = `${date}T00:00:00.000Z`;
  const end = `${date}T23:59:59.999Z`;
  const { data: flightData, error: flightError } = await client
    .from("recruitment_flights")
    .select(
      "id, application_id, departure_at, arrival_at, origin, destination, flight_number, status",
    )
    .eq("company_id", companyId)
    .gte("departure_at", start)
    .lte("departure_at", end)
    .order("departure_at", { ascending: true })
    .limit(300);
  if (flightError) throw flightError;
  const flights = (flightData ?? []) as FlightRow[];
  const applicationIds = [...new Set(flights.map((item) => item.application_id).filter(Boolean))];
  const candidateResponse = applicationIds.length === 0
    ? { data: [] as unknown[], error: null }
    : await client
      .from("recruitment_applications")
      .select("id, full_name")
      .in("id", applicationIds);
  if (candidateResponse.error) throw candidateResponse.error;
  const names = new Map(
    ((candidateResponse.data ?? []) as CandidateRow[]).map((item) => [item.id, item.full_name]),
  );
  const value = normalized(prompt);
  const wantsArrivals = /(?:прилет|прибы)/.test(value);
  const selected = wantsArrivals
    ? flights.filter((item) => item.arrival_at && item.arrival_at!.slice(0, 10) === date)
    : flights;
  const highlights = selected.slice(0, 25).map((item) => {
    const name = names.get(item.application_id) ?? "Кандидат";
    const time = (wantsArrivals ? item.arrival_at : item.departure_at)?.slice(11, 16) ?? "";
    return `${time} · ${name} · ${item.origin} → ${item.destination}${item.flight_number ? ` · ${item.flight_number}` : ""} · ${item.status}`;
  });

  return {
    body: readResult({
      title: wantsArrivals ? "Прилёты" : "Вылеты",
      summary: `${date}: ${selected.length} ${wantsArrivals ? "прилётов" : "вылетов"}.`,
      highlights,
      warnings: [ifMore(selected.length, highlights.length)].filter(Boolean),
      date,
    }),
    status: 200,
  };
}

async function milestoneSummary({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
  date: string;
}) {
  if (!milestoneRole(role)) {
    return { error: "Сводка по целям недоступна текущей роли", status: 403 };
  }
  const objectName = await resolveObjectName({
    client,
    companyId,
    role,
    assignedObject,
    requestedObject,
    prompt,
  });
  const allowedObjects = objectName
    ? [objectName]
    : await activeObjectNames(client, companyId);
  if (allowedObjects.length === 0) {
    return { error: "Нет доступных объектов для сводки по целям", status: 400 };
  }

  const { data, error } = await client
    .from("project_milestones")
    .select("id, object_name, title, status, target_date")
    .in("object_name", allowedObjects)
    .order("target_date", { ascending: true })
    .limit(500);
  if (error) throw error;
  const rows = (data ?? []) as MilestoneRow[];
  const value = normalized(prompt);
  const wantsOverdue = /просроч/.test(value);
  const selected = wantsOverdue
    ? rows.filter(
      (item) => item.target_date < date && item.status !== "completed",
    )
    : rows.filter((item) => item.status !== "completed");
  const highlights = selected.slice(0, 25).map(
    (item) => `${item.target_date} · ${item.object_name} · ${item.title} · ${item.status}`,
  );

  return {
    body: readResult({
      title: wantsOverdue ? "Просроченные цели" : "Открытые цели",
      summary: `${objectName ? `${objectName}: ` : ""}${selected.length} ${wantsOverdue ? "просроченных" : "открытых"} целей.`,
      highlights,
      warnings: [ifMore(selected.length, highlights.length)].filter(Boolean),
      objectName,
      date,
    }),
    status: 200,
  };
}

export async function buildExtendedOperationalQuery({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
  date: string;
}) {
  const value = normalized(prompt);
  if (attendanceIntent(value)) {
    return attendanceSummary({
      client,
      companyId,
      role,
      assignedObject,
      requestedObject,
      prompt,
      date,
    });
  }
  if (financeIntent(value)) {
    return financeSummary({
      client,
      companyId,
      role,
      requestedObject,
      prompt,
      date,
    });
  }
  if (legalReadIntent(value)) {
    return legalSummary({ client, companyId, role, prompt, date });
  }
  if (flightReadIntent(value)) {
    return flightSummary({ client, companyId, role, prompt, date });
  }
  if (milestoneReadIntent(value)) {
    return milestoneSummary({
      client,
      companyId,
      role,
      assignedObject,
      requestedObject,
      prompt,
      date,
    });
  }
  return { error: "Не понял расширенную оперативную сводку", status: 400 };
}
