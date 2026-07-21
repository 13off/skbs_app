import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonMap = Record<string, unknown>;
type EmployeeRow = {
  id: string;
  fio: string;
  position: string;
  phone: string;
  object_name: string;
  daily_rate: number;
};
type CandidateRow = {
  id: string;
  full_name: string;
  phone: string;
  citizenship: string;
  position_title: string;
  status: string;
  consent_personal_data: boolean;
  object_id: string | null;
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

function clean(value: unknown, max = 4000): string {
  return String(value ?? "").trim().slice(0, max);
}

function normalized(value: unknown): string {
  return clean(value)
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/[–—−]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
}

function tokens(value: unknown): string[] {
  return normalized(value)
    .replace(/[^а-яa-z0-9-]+/g, " ")
    .split(" ")
    .filter((token) => token.length >= 4);
}

function nameMatches(prompt: string, fullName: string): boolean {
  const promptTokens = new Set(tokens(prompt));
  return tokens(fullName).some((nameToken) => {
    for (const promptToken of promptTokens) {
      if (promptToken === nameToken) return true;
      if (
        Math.min(promptToken.length, nameToken.length) >= 5 &&
        (promptToken.startsWith(nameToken) || nameToken.startsWith(promptToken))
      ) return true;
    }
    return false;
  });
}

function dateKey(year: number | string, month: number | string, day: number | string) {
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function baseDate(value: unknown): Date {
  const text = clean(value, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
    const parsed = new Date(`${text}T00:00:00.000Z`);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

function requestedDate(prompt: string, base: Date): string {
  const value = normalized(prompt);
  const iso = value.match(/\b(20\d{2})-(\d{1,2})-(\d{1,2})\b/);
  if (iso) return dateKey(iso[1], iso[2], iso[3]);
  const ru = value.match(/\b(\d{1,2})[.\/](\d{1,2})(?:[.\/](20\d{2}))?\b/);
  if (ru) return dateKey(ru[3] ?? base.getUTCFullYear(), ru[2], ru[1]);
  const result = new Date(base.getTime());
  if (/послезавтра/.test(value)) result.setUTCDate(result.getUTCDate() + 2);
  else if (/завтра/.test(value)) result.setUTCDate(result.getUTCDate() + 1);
  return dateKey(result.getUTCFullYear(), result.getUTCMonth() + 1, result.getUTCDate());
}

function requestedMonth(prompt: string, base: Date): string {
  const value = normalized(prompt);
  const yearMatch = value.match(/\b(20\d{2})\b/);
  const monthNames: Array<[RegExp, number]> = [
    [/январ/, 1], [/феврал/, 2], [/март/, 3], [/апрел/, 4], [/ма[йя]/, 5],
    [/июн/, 6], [/июл/, 7], [/август/, 8], [/сентябр/, 9], [/октябр/, 10],
    [/ноябр/, 11], [/декабр/, 12],
  ];
  let month = base.getUTCMonth() + 1;
  for (const [pattern, valueMonth] of monthNames) {
    if (pattern.test(value)) {
      month = valueMonth;
      break;
    }
  }
  const year = yearMatch ? Number(yearMatch[1]) : base.getUTCFullYear();
  return `${year}-${String(month).padStart(2, "0")}`;
}

function requestedTime(prompt: string): string {
  const value = normalized(prompt);
  const match = value.match(/(?:в|на)\s*(\d{1,2})(?::(\d{2}))?\b/);
  if (!match) return "09:00";
  const hour = Math.max(0, Math.min(23, Number(match[1])));
  const minute = Math.max(0, Math.min(59, Number(match[2] ?? 0)));
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

function moneyFromPrompt(prompt: string): number {
  const value = normalized(prompt);
  const match = value.match(/(\d[\d\s]{2,})(?:\s*(?:руб|₽))?/);
  return match ? Number(match[1].replace(/\s/g, "")) : Number.NaN;
}

function paymentType(prompt: string): string {
  const value = normalized(prompt);
  if (/штраф/.test(value)) return "fine";
  if (/зарплат|заработн/.test(value)) return "salary";
  return "advance";
}

function kind(prompt: string): string {
  const value = normalized(prompt);
  if (/напомн|напоминан/.test(value)) return "create_reminder";
  if (/(?:пакет|комплект).*(?:документ).*(?:кандидат|соискател)/.test(value) ||
      /(?:подготов|собер|проверь).*(?:документ).*(?:кандидат|соискател)/.test(value)) {
    return "prepare_candidate_documents";
  }
  if (/(?:нет|отсутств|без|не прикреп).*(?:чек)/.test(value) ||
      /(?:найд|покаж|проверь|какие).*(?:чек).*(?:нет|отсутств|не прикреп|без)/.test(value)) {
    return "find_missing_receipts";
  }
  if (/(?:сформир|подготов|созда|сдел).*(?:акт).*(?:выполн|работ|задач)/.test(value)) {
    return "prepare_work_act";
  }
  if (/(?:открой|покаж|собер|сформир).*(?:месячн|за месяц|период).*(?:табел)/.test(value)) {
    return "open_period_timesheet";
  }
  if (/(?:добав|созда|оформ).*(?:сотрудник|работник|человек)/.test(value)) {
    return "create_employee_draft";
  }
  if (/(?:подготов|добав|созда|провед|внес).*(?:выплат|аванс|зарплат|штраф)/.test(value)) {
    return "prepare_payment";
  }
  if (/(?:исправ|измен|поправ|постав|отмет).*(?:табел|смен)/.test(value) ||
      /(?:табел|смен).*(?:исправ|измен|поправ|постав|отмет)/.test(value)) {
    return "prepare_timesheet_correction";
  }
  if (/(?:измен|обнов|постав).*(?:ставк|должност|телефон)/.test(value)) {
    return "prepare_employee_update";
  }
  return "unknown";
}

function actionResponse({
  type, title, button, summary, highlights, warnings, payload, objectName, date,
}: {
  type: string;
  title: string;
  button: string;
  summary: string;
  highlights: string[];
  warnings: string[];
  payload: JsonMap;
  objectName: string;
  date: string;
}) {
  return {
    ok: true,
    mode: "action_draft",
    title,
    summary,
    highlights,
    warnings,
    next_steps: ["Проверь все значения и явно подтверди действие."],
    scope: { object_name: objectName || "Все доступные объекты", date },
    preliminary: true,
    ai_used: false,
    action: {
      id: crypto.randomUUID(),
      type,
      title,
      button_label: button,
      confirmation_required: true,
      payload,
    },
  };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Метод не поддерживается" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !authorization) {
      return json({ error: "Сервис действий не настроен" }, 500);
    }

    const client = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: userError } = await client.auth.getUser();
    if (userError || !user) return json({ error: "Требуется повторный вход" }, 401);

    const input = await request.json().catch(() => ({})) as JsonMap;
    const companyId = clean(input.company_id, 80);
    const requestedObject = clean(input.object_name, 180);
    const prompt = clean(input.prompt, 4000);
    const base = baseDate(input.date);
    if (!companyId || !prompt) return json({ error: "Недостаточно данных запроса" }, 400);

    const { data: profile, error: profileError } = await client
      .from("user_profiles")
      .select("role, object_name, active_company_id, is_active")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.is_active !== true) return json({ error: "Профиль пользователя недоступен" }, 403);
    if (clean(profile.active_company_id, 80) !== companyId) {
      return json({ error: "Помощник работает только с активной компанией" }, 403);
    }

    const { data: membership, error: membershipError } = await client
      .from("company_memberships")
      .select("role")
      .eq("company_id", companyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return json({ error: "Нет доступа к выбранной компании" }, 403);

    const profileRole = clean(profile.role, 30);
    const membershipRole = clean(membership.role, 30);
    const roles = new Set([profileRole, membershipRole]);
    const isAdmin = roles.has("admin") || roles.has("owner");
    const isDeveloper = roles.has("developer");
    const isHr = roles.has("hr");
    const isAccounting = roles.has("accounting");
    const isForeman = roles.has("foreman");
    const assignedObject = clean(profile.object_name, 180);
    const objectName = isForeman ? assignedObject : requestedObject;
    if (isForeman && !objectName) return json({ error: "Прорабу не назначен объект" }, 403);

    const actionKind = kind(prompt);
    if (actionKind === "unknown") return json({ error: "Не удалось определить операционное действие" }, 400);
    if (["prepare_employee_update", "create_employee_draft"].includes(actionKind) && !isAdmin && !isHr && !isDeveloper) {
      return json({ error: "Работа с сотрудниками доступна руководителю или HR" }, 403);
    }
    if (["prepare_payment", "find_missing_receipts"].includes(actionKind) && !isAdmin && !isAccounting && !isDeveloper) {
      return json({ error: "Выплаты доступны руководителю или бухгалтеру" }, 403);
    }
    if (actionKind === "prepare_candidate_documents" && !isAdmin && !isHr && !isDeveloper) {
      return json({ error: "Пакет кандидата доступен руководителю или HR" }, 403);
    }
    if (actionKind === "create_reminder" && !isAdmin && !isDeveloper) {
      return json({ error: "Системные напоминания доступны руководителю или разработчику" }, 403);
    }

    let employeeQuery: any = client
      .from("employees")
      .select("id, fio, position, phone, object_name, daily_rate")
      .eq("company_id", companyId)
      .is("archived_at", null)
      .order("fio");
    if (objectName) employeeQuery = employeeQuery.eq("object_name", objectName);
    const { data: employeeRows, error: employeeError } = await employeeQuery;
    if (employeeError) throw employeeError;
    const employees = (employeeRows ?? []) as EmployeeRow[];
    const employeeMatches = employees.filter((employee) => nameMatches(prompt, employee.fio));
    const employee = employeeMatches.length === 1 ? employeeMatches[0] : null;
    const date = requestedDate(prompt, base);

    if (actionKind === "create_employee_draft") {
      if (!objectName) return json({ error: "Выбери конкретный объект для сотрудника" }, 400);
      const value = clean(prompt.replace(/.*?(?:сотрудника|работника|человека)\s*/i, ""), 240);
      const beforePosition = value.split(/\s+(?:на должность|должность|как)\s+/i);
      const fio = clean(beforePosition[0], 120);
      const positionMatch = normalized(prompt).match(/(?:на должность|должность|как)\s+([^,.;]+?)(?:\s+(?:ставк|телефон)|$)/);
      const position = clean(positionMatch?.[1], 100);
      const phoneMatch = prompt.match(/(?:\+7|8)[\d\s()+-]{9,}/);
      const rateMatch = normalized(prompt).match(/(?:ставк[^\d]*)(\d[\d\s]{2,})/);
      const dailyRate = rateMatch ? Number(rateMatch[1].replace(/\s/g, "")) : 6000;
      if (fio.length < 5) return json({ error: "Укажи ФИО нового сотрудника" }, 400);
      return json(actionResponse({
        type: actionKind,
        title: "Карточка нового сотрудника подготовлена",
        button: "Открыть карточку сотрудника",
        summary: `${fio}. Объект: ${objectName}.`,
        highlights: [`ФИО: ${fio}`, `Объект: ${objectName}`, position ? `Должность: ${position}` : "Должность нужно проверить", `Ставка: ${dailyRate}`],
        warnings: ["Сотрудник будет создан только после сохранения обычной формы."],
        objectName,
        date,
        payload: { fio, position, phone: clean(phoneMatch?.[0], 40), object_name: objectName, daily_rate: dailyRate, comment: "Создано из проверенного черновика ИИ", source_prompt: prompt },
      }));
    }

    if (actionKind === "prepare_payment") {
      if (!employee) return json({ error: "Укажи одного сотрудника для выплаты" }, 400);
      const amount = moneyFromPrompt(prompt);
      if (!Number.isFinite(amount) || amount <= 0) return json({ error: "Укажи сумму выплаты" }, 400);
      const type = paymentType(prompt);
      return json(actionResponse({
        type: actionKind,
        title: "Черновик выплаты подготовлен",
        button: "Открыть форму выплаты",
        summary: `${employee.fio}: ${amount} ₽.`,
        highlights: [`Сотрудник: ${employee.fio}`, `Объект: ${employee.object_name}`, `Сумма: ${amount} ₽`, `Дата: ${date}`],
        warnings: ["Чек и остальные поля нужно проверить перед сохранением."],
        objectName: employee.object_name,
        date,
        payload: { employee_id: employee.id, employee_name: employee.fio, object_name: employee.object_name, amount, payment_type: type, date, comment: "Подготовлено ИИ", source_prompt: prompt },
      }));
    }

    if (actionKind === "find_missing_receipts") {
      const month = requestedMonth(prompt, base);
      const [yearText, monthText] = month.split("-");
      let scopedEmployees = employees;
      if (!objectName) {
        const { data: allRows, error: allError } = await client
          .from("employees")
          .select("id, fio, position, phone, object_name, daily_rate")
          .eq("company_id", companyId)
          .is("archived_at", null);
        if (allError) throw allError;
        scopedEmployees = (allRows ?? []) as EmployeeRow[];
      }
      const employeeById = new Map(scopedEmployees.map((item) => [item.id, item]));
      const employeeIds = [...employeeById.keys()];
      let rows: any[] = [];
      if (employeeIds.length > 0) {
        const { data: paymentRows, error: paymentError } = await client
          .from("payments")
          .select("id, employee_id, payment_date, amount, payment_type, comment")
          .eq("company_id", companyId)
          .eq("period_year", Number(yearText))
          .eq("period_month", Number(monthText))
          .in("employee_id", employeeIds)
          .order("payment_date", { ascending: false });
        if (paymentError) throw paymentError;
        const paymentIds = (paymentRows ?? []).map((row) => clean(row.id, 80));
        const receiptPaymentIds = new Set<string>();
        if (paymentIds.length > 0) {
          const { data: receiptRows, error: receiptError } = await client
            .from("payment_receipts")
            .select("payment_id")
            .eq("company_id", companyId)
            .in("payment_id", paymentIds);
          if (receiptError) throw receiptError;
          for (const receipt of receiptRows ?? []) receiptPaymentIds.add(clean(receipt.payment_id, 80));
        }
        rows = (paymentRows ?? []).filter((row) => !receiptPaymentIds.has(clean(row.id, 80))).map((row) => {
          const worker = employeeById.get(clean(row.employee_id, 80));
          return { payment_id: row.id, employee_id: row.employee_id, employee_name: worker?.fio ?? "Сотрудник", object_name: worker?.object_name ?? "", payment_date: row.payment_date, amount: row.amount, payment_type: row.payment_type, comment: row.comment };
        });
      }
      return json(actionResponse({
        type: actionKind,
        title: "Выплаты без чеков найдены",
        button: "Открыть список",
        summary: rows.length === 0 ? `За ${month} выплат без чеков не найдено.` : `За ${month} без чеков: ${rows.length}.`,
        highlights: [`Период: ${month}`, `Найдено: ${rows.length}`, objectName ? `Объект: ${objectName}` : "Все доступные объекты"],
        warnings: rows.length > 0 ? ["Список сформирован только для проверки и ничего не изменяет."] : [],
        objectName,
        date,
        payload: { month, object_name: objectName, rows, source_prompt: prompt },
      }));
    }

    if (actionKind === "open_period_timesheet") {
      const month = requestedMonth(prompt, base);
      return json(actionResponse({
        type: actionKind,
        title: "Месячный табель подготовлен",
        button: "Открыть месячный табель",
        summary: `Период: ${month}.`,
        highlights: [`Период: ${month}`, objectName ? `Объект: ${objectName}` : "Все доступные объекты"],
        warnings: ["Откроется действующий отчёт приложения."],
        objectName,
        date,
        payload: { month, object_name: objectName, source_prompt: prompt },
      }));
    }

    if (actionKind === "prepare_work_act") {
      return json(actionResponse({
        type: actionKind,
        title: "Черновик акта подготовлен",
        button: "Открыть акт выполненных работ",
        summary: `Выполненные задачи за ${date}.`,
        highlights: [`Дата: ${date}`, objectName ? `Объект: ${objectName}` : "Все доступные объекты"],
        warnings: ["В акт попадут только задачи со статусом «Выполнено»."],
        objectName,
        date,
        payload: { date, object_name: objectName, source_prompt: prompt },
      }));
    }

    if (actionKind === "prepare_candidate_documents") {
      const { data: candidateRows, error: candidateError } = await client
        .from("recruitment_applications")
        .select("id, full_name, phone, citizenship, position_title, status, consent_personal_data, object_id")
        .eq("company_id", companyId)
        .is("archived_at", null)
        .order("updated_at", { ascending: false });
      if (candidateError) throw candidateError;
      const matches = ((candidateRows ?? []) as CandidateRow[]).filter((candidate) => nameMatches(prompt, candidate.full_name));
      const candidate = matches.length === 1 ? matches[0] : null;
      if (!candidate) return json({ error: "Укажи одного кандидата из подбора" }, 400);
      const { data: documentRows, error: documentError } = await client
        .from("recruitment_documents")
        .select("document_type, original_name, mime_type")
        .eq("company_id", companyId)
        .eq("application_id", candidate.id)
        .eq("is_test_copy", false);
      if (documentError) throw documentError;
      const existingDocuments = (documentRows ?? []).map((row) => ({ document_type: row.document_type, original_name: row.original_name, mime_type: row.mime_type }));
      const existingTypes = new Set(existingDocuments.map((row) => clean(row.document_type, 80)));
      const required = ["passport", "snils", "inn"];
      const missingDocuments = required.filter((type) => !existingTypes.has(type));
      return json(actionResponse({
        type: actionKind,
        title: "Пакет документов кандидата подготовлен",
        button: "Открыть пакет кандидата",
        summary: `${candidate.full_name}: документов ${existingDocuments.length}, не хватает ${missingDocuments.length}.`,
        highlights: [`Кандидат: ${candidate.full_name}`, `Должность: ${candidate.position_title || "Не указана"}`, `Получено файлов: ${existingDocuments.length}`, `Не хватает: ${missingDocuments.length}`],
        warnings: ["Персональные реквизиты не передаются ИИ. Пакет показывает только статус и исходные формы."],
        objectName,
        date,
        payload: { application_id: candidate.id, full_name: candidate.full_name, phone: candidate.phone, citizenship: candidate.citizenship, position_title: candidate.position_title, status: candidate.status, consent_personal_data: candidate.consent_personal_data, existing_documents: existingDocuments, missing_documents: missingDocuments, source_prompt: prompt },
      }));
    }

    if (actionKind === "prepare_timesheet_correction") {
      if (!employee) return json({ error: "Укажи одного сотрудника для корректировки табеля" }, 400);
      const shiftMatch = normalized(prompt).match(/(\d+(?:[.,]\d+)?)\s*(?:смен|смены|смену)?/);
      const shifts = shiftMatch ? Number(shiftMatch[1].replace(",", ".")) : Number.NaN;
      if (!Number.isFinite(shifts) || shifts < 0 || shifts > 3) return json({ error: "Укажи количество смен от 0 до 3" }, 400);
      return json(actionResponse({
        type: actionKind,
        title: "Корректировка табеля подготовлена",
        button: "Проверить и применить",
        summary: `${employee.fio}: ${shifts} смены за ${date}.`,
        highlights: [`Сотрудник: ${employee.fio}`, `Объект: ${employee.object_name}`, `Дата: ${date}`, `Новое значение: ${shifts}`],
        warnings: ["После подтверждения запись табеля будет изменена."],
        objectName: employee.object_name,
        date,
        payload: { employee_id: employee.id, employee_name: employee.fio, object_name: employee.object_name, date, shifts, source_prompt: prompt },
      }));
    }

    if (actionKind === "prepare_employee_update") {
      if (!employee) return json({ error: "Укажи одного сотрудника для изменения" }, 400);
      const rateMatch = normalized(prompt).match(/(?:ставк[^\d]*)(\d[\d\s]{2,})/);
      const dailyRate = rateMatch ? Number(rateMatch[1].replace(/\s/g, "")) : Number.NaN;
      if (!Number.isFinite(dailyRate) || dailyRate <= 0) return json({ error: "Сейчас поддерживается изменение ставки: укажи новую сумму" }, 400);
      return json(actionResponse({
        type: actionKind,
        title: "Изменение сотрудника подготовлено",
        button: "Открыть карточку изменения",
        summary: `${employee.fio}: ставка ${employee.daily_rate} → ${dailyRate}.`,
        highlights: [`Сотрудник: ${employee.fio}`, `Объект: ${employee.object_name}`, `Текущая ставка: ${employee.daily_rate}`, `Новая ставка: ${dailyRate}`],
        warnings: ["Обычная форма редактирования откроется после подтверждения."],
        objectName: employee.object_name,
        date,
        payload: { employee_id: employee.id, employee_name: employee.fio, object_name: employee.object_name, current_daily_rate: employee.daily_rate, daily_rate: dailyRate, source_prompt: prompt },
      }));
    }

    const time = requestedTime(prompt);
    const reminderTitle = clean(prompt.replace(/напомни(?:ть)?/i, ""), 120) || "Рабочее напоминание";
    return json(actionResponse({
      type: actionKind,
      title: "Напоминание подготовлено",
      button: "Открыть настройки напоминания",
      summary: `${reminderTitle}. ${date} в ${time}.`,
      highlights: [`Название: ${reminderTitle}`, `Дата: ${date}`, `Время: ${time}`, objectName ? `Объект: ${objectName}` : "Все объекты"],
      warnings: ["Получателей, push и точное расписание нужно проверить в конструкторе."],
      objectName,
      date,
      payload: { title: reminderTitle, message: prompt, object_name: objectName, date, local_time: time, schedule_type: "once", recipient_roles: ["admin"], source_prompt: prompt },
    }));
  } catch (error) {
    console.error("ai operational draft failed", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
