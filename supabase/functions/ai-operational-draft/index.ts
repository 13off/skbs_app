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

function employeeMatches(prompt: string, employee: EmployeeRow): boolean {
  const promptTokens = new Set(tokens(prompt));
  return tokens(employee.fio).some((nameToken) => {
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

function requestedTime(prompt: string): string {
  const value = normalized(prompt);
  const match = value.match(/(?:в|на)\s*(\d{1,2})(?::(\d{2}))?\b/);
  if (!match) return "09:00";
  const hour = Math.max(0, Math.min(23, Number(match[1])));
  const minute = Math.max(0, Math.min(59, Number(match[2] ?? 0)));
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

function kind(prompt: string): string {
  const value = normalized(prompt);
  if (/напомн|напоминан/.test(value)) return "create_reminder";
  if (
    /(?:исправ|измен|поправ|постав|отмет).*(?:табел|смен)/.test(value) ||
    /(?:табел|смен).*(?:исправ|измен|поправ|постав|отмет)/.test(value)
  ) return "prepare_timesheet_correction";
  if (
    /(?:измен|обнов|постав).*(?:ставк|должност|телефон).*сотрудник?/.test(value) ||
    /(?:измен|обнов|постав).*(?:ставк|должност|телефон)/.test(value)
  ) return "prepare_employee_update";
  return "unknown";
}

function actionResponse({
  type,
  title,
  button,
  summary,
  highlights,
  warnings,
  payload,
  objectName,
  date,
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
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Метод не поддерживается" }, 405);
  }

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
    const {
      data: { user },
      error: userError,
    } = await client.auth.getUser();
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
    if (!profile || profile.is_active !== true) {
      return json({ error: "Профиль пользователя недоступен" }, 403);
    }
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
    const isAdmin = profileRole === "admin" || ["owner", "admin"].includes(membershipRole);
    const isDeveloper = profileRole === "developer" || membershipRole === "developer";
    const isForeman = profileRole === "foreman" || membershipRole === "foreman";
    const assignedObject = clean(profile.object_name, 180);
    const objectName = isForeman ? assignedObject : requestedObject;
    if (isForeman && !objectName) return json({ error: "Прорабу не назначен объект" }, 403);

    const actionKind = kind(prompt);
    if (actionKind === "unknown") {
      return json({ error: "Не удалось определить операционное действие" }, 400);
    }
    if (actionKind === "prepare_employee_update" && !isAdmin) {
      return json({ error: "Изменение сотрудника доступно руководителю" }, 403);
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
    const matches = employees.filter((employee) => employeeMatches(prompt, employee));
    const employee = matches.length === 1 ? matches[0] : null;
    const date = requestedDate(prompt, base);

    if (actionKind === "prepare_timesheet_correction") {
      if (!employee) {
        return json({ error: "Укажи одного сотрудника для корректировки табеля" }, 400);
      }
      const shiftMatch = normalized(prompt).match(/(\d+(?:[.,]\d+)?)\s*(?:смен|смены|смену)?/);
      const shifts = shiftMatch ? Number(shiftMatch[1].replace(",", ".")) : Number.NaN;
      if (!Number.isFinite(shifts) || shifts < 0 || shifts > 3) {
        return json({ error: "Укажи количество смен от 0 до 3" }, 400);
      }
      return json(actionResponse({
        type: actionKind,
        title: "Корректировка табеля подготовлена",
        button: "Проверить и применить",
        summary: `${employee.fio}: ${shifts} смены за ${date}.`,
        highlights: [
          `Сотрудник: ${employee.fio}`,
          `Объект: ${employee.object_name}`,
          `Дата: ${date}`,
          `Новое значение: ${shifts}`,
        ],
        warnings: ["После подтверждения запись табеля будет изменена."],
        objectName: employee.object_name,
        date,
        payload: {
          employee_id: employee.id,
          employee_name: employee.fio,
          object_name: employee.object_name,
          date,
          shifts,
          source_prompt: prompt,
        },
      }));
    }

    if (actionKind === "prepare_employee_update") {
      if (!employee) return json({ error: "Укажи одного сотрудника для изменения" }, 400);
      const rateMatch = normalized(prompt).match(/(?:ставк[^\d]*)(\d[\d\s]{2,})/);
      const dailyRate = rateMatch ? Number(rateMatch[1].replace(/\s/g, "")) : Number.NaN;
      if (!Number.isFinite(dailyRate) || dailyRate <= 0) {
        return json({ error: "Сейчас поддерживается изменение ставки: укажи новую сумму" }, 400);
      }
      return json(actionResponse({
        type: actionKind,
        title: "Изменение сотрудника подготовлено",
        button: "Открыть карточку изменения",
        summary: `${employee.fio}: ставка ${employee.daily_rate} → ${dailyRate}.`,
        highlights: [
          `Сотрудник: ${employee.fio}`,
          `Объект: ${employee.object_name}`,
          `Текущая ставка: ${employee.daily_rate}`,
          `Новая ставка: ${dailyRate}`,
        ],
        warnings: ["Обычная форма редактирования откроется после подтверждения."],
        objectName: employee.object_name,
        date,
        payload: {
          employee_id: employee.id,
          employee_name: employee.fio,
          object_name: employee.object_name,
          current_daily_rate: employee.daily_rate,
          daily_rate: dailyRate,
          source_prompt: prompt,
        },
      }));
    }

    const time = requestedTime(prompt);
    const reminderTitle = clean(prompt.replace(/напомни(?:ть)?/i, ""), 120) || "Рабочее напоминание";
    return json(actionResponse({
      type: actionKind,
      title: "Напоминание подготовлено",
      button: "Открыть настройки напоминания",
      summary: `${reminderTitle}. ${date} в ${time}.`,
      highlights: [
        `Название: ${reminderTitle}`,
        `Дата: ${date}`,
        `Время: ${time}`,
        objectName ? `Объект: ${objectName}` : "Все объекты",
      ],
      warnings: ["Получателей, push и точное расписание нужно проверить в конструкторе."],
      objectName,
      date,
      payload: {
        title: reminderTitle,
        message: prompt,
        object_name: objectName,
        date,
        local_time: time,
        schedule_type: "once",
        recipient_roles: ["admin"],
        source_prompt: prompt,
      },
    }));
  } catch (error) {
    console.error("ai operational draft failed", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
