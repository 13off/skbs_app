import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type EmployeeRow = {
  id: string;
  fio: string;
  object_name: string;
};

type ObjectRow = {
  name: string;
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
    .replace(/[^а-яa-z0-9.,-]+/g, " ")
    .split(" ")
    .filter(Boolean);
}

function dateKey(year: number, month: number, day: number) {
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
  if (iso) return dateKey(Number(iso[1]), Number(iso[2]), Number(iso[3]));
  const ru = value.match(/\b(\d{1,2})[./](\d{1,2})(?:[./](20\d{2}))?\b/);
  if (ru) {
    return dateKey(Number(ru[3] ?? base.getUTCFullYear()), Number(ru[2]), Number(ru[1]));
  }
  const result = new Date(base.getTime());
  if (/послезавтра/.test(value)) result.setUTCDate(result.getUTCDate() + 2);
  else if (/завтра/.test(value)) result.setUTCDate(result.getUTCDate() + 1);
  else if (/вчера/.test(value)) result.setUTCDate(result.getUTCDate() - 1);
  return dateKey(result.getUTCFullYear(), result.getUTCMonth() + 1, result.getUTCDate());
}

function nameTokens(fullName: string): string[] {
  return tokens(fullName).filter((token) => token.length >= 3);
}

function nameMatches(prompt: string, fullName: string): boolean {
  const promptTokens = new Set(tokens(prompt));
  return nameTokens(fullName).some((nameToken) => {
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

function shiftValueFromText(value: string): number | null {
  const text = normalized(value);
  if (/два\s+с\s+половин|две\s+с\s+половин/.test(text)) return 2.5;
  if (/полтор(?:а|ы)/.test(text)) return 1.5;
  if (/пол\s*смен|половин(?:а|у|ы)/.test(text)) return 0.5;
  if (/\b(?:ноль|нолик|нулев(?:ая|ую|ой)|нул[ья])\b/.test(text)) return 0;
  if (/\b(?:единичк(?:а|у|и)|единиц(?:а|у|ы)|один|одну)\b/.test(text)) return 1;
  if (/\b(?:двойк(?:а|у|и)|два|две)\b/.test(text)) return 2;
  if (/\b(?:тройк(?:а|у|и)|три)\b/.test(text)) return 3;
  const numeric = text.match(/(?:^|\s)([0-3](?:[.,]\d)?)(?=\s|$|[,.;])/);
  if (!numeric) return null;
  const parsed = Number(numeric[1].replace(",", "."));
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 3) return null;
  const tenths = parsed * 10;
  if (Math.abs(tenths - Math.round(tenths)) > 0.000001) return null;
  return parsed;
}

function defaultBulkShift(prompt: string): number | null {
  const value = normalized(prompt);
  const marker = value.match(/\b(?:всем|всех|каждому|все)\b/);
  if (!marker || marker.index == null) return null;
  const tail = value.slice(marker.index + marker[0].length);
  const firstSegment = tail.split(/[,;]|\s+а\s+/)[0] ?? tail;
  return shiftValueFromText(firstSegment);
}

function shiftNearEmployee(prompt: string, employee: EmployeeRow): number | null {
  const value = normalized(prompt);
  const candidates = nameTokens(employee.fio).sort((a, b) => b.length - a.length);
  for (const token of candidates) {
    const index = value.indexOf(token);
    if (index < 0) continue;
    const after = value.slice(index + token.length, index + token.length + 70);
    const before = value.slice(Math.max(0, index - 35), index);
    const next = shiftValueFromText(after);
    if (next != null) return next;
    const previous = shiftValueFromText(before);
    if (previous != null) return previous;
  }
  return null;
}

function bulkTimesheetIntent(prompt: string): boolean {
  const value = normalized(prompt);
  const hasEveryone = /\b(?:всем|всех|каждому|все)\b/.test(value);
  const hasWrite = /(?:постав|простав|отмет|заполн|табел|смен)/.test(value);
  return hasEveryone && hasWrite && defaultBulkShift(value) != null;
}

function navigationTarget(prompt: string): { screen: string; title: string } | null {
  const value = normalized(prompt);
  if (!/^(?:открой|открыть|перейди|перейти|зайди|зайти)\b/.test(value)) {
    return null;
  }
  const targets: Array<[RegExp, string, string]> = [
    [/(?:уведомлен)/, "notifications", "Уведомления"],
    [/(?:настройк)/, "settings", "Настройки"],
    [/(?:сотрудник|люд)/, "employees", "Сотрудники"],
    [/(?:табел)/, "timesheet", "Табель"],
    [/(?:задач)/, "tasks", "Задачи"],
    [/(?:выплат|бухгалтер)/, "payments", "Выплаты"],
    [/(?:кандидат|подбор|hr)/, "recruitment", "HR и кандидаты"],
    [/(?:юрид|юрист|договор)/, "legal", "Юридическое"],
    [/(?:снабжен|закуп|заявк)/, "procurement", "Снабжение"],
    [/(?:поставщик)/, "suppliers", "Поставщики"],
    [/(?:доставк)/, "deliveries", "Доставки"],
    [/(?:цел|этап)/, "milestones", "Цели"],
    [/(?:инструмент|трудоустрой)/, "tools", "Инструменты"],
  ];
  for (const [pattern, screen, title] of targets) {
    if (pattern.test(value)) return { screen, title };
  }
  return null;
}

function resultWithAction({
  title,
  summary,
  highlights = [],
  warnings = [],
  objectName = "",
  date,
  action,
}: {
  title: string;
  summary: string;
  highlights?: string[];
  warnings?: string[];
  objectName?: string;
  date: string;
  action: Record<string, unknown>;
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
    preliminary: true,
    ai_used: false,
    action,
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
    const publishable =
      Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !publishable || !authorization) {
      return json({ error: "Сервис голосовых команд не настроен" }, 500);
    }

    const client = createClient(supabaseUrl, publishable, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await client.auth.getUser();
    if (userError || !user) return json({ error: "Требуется повторный вход" }, 401);

    const input = await request.json().catch(() => ({}));
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
      return json({ error: "Команда работает только с активной компанией" }, 403);
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

    const roles = new Set([
      clean(profile.role, 30),
      clean(membership.role, 30),
    ]);
    const isAdmin = roles.has("admin") || roles.has("owner") || roles.has("developer");
    const isForeman = roles.has("foreman");
    const assignedObject = clean(profile.object_name, 180);

    const date = requestedDate(prompt, base);
    const navigation = navigationTarget(prompt);
    if (navigation != null) {
      return json(resultWithAction({
        title: navigation.title,
        summary: `Открыть раздел «${navigation.title}».`,
        date,
        objectName: isForeman ? assignedObject : requestedObject,
        action: {
          id: crypto.randomUUID(),
          type: "open_screen",
          title: `Открыть ${navigation.title}`,
          button_label: "Открыть",
          confirmation_required: false,
          payload: {
            screen: navigation.screen,
            object_name: isForeman ? assignedObject : requestedObject,
            source_prompt: prompt,
          },
        },
      }));
    }

    if (!bulkTimesheetIntent(prompt)) {
      return json({ fallback: true });
    }

    if (!isAdmin && !isForeman) {
      return json({ error: "Массовый табель доступен руководителю или прорабу" }, 403);
    }

    let objectName = isForeman ? assignedObject : requestedObject;
    const { data: objectRows, error: objectsError } = await client
      .from("objects")
      .select("name")
      .eq("company_id", companyId)
      .eq("is_active", true)
      .order("name");
    if (objectsError) throw objectsError;
    const objects = (objectRows ?? []) as ObjectRow[];

    if (!objectName) {
      const matched = objects.filter((item) => nameMatches(prompt, item.name));
      if (matched.length === 1) objectName = clean(matched[0].name, 180);
      else if (objects.length === 1) objectName = clean(objects[0].name, 180);
    }
    if (!objectName) {
      return json({
        error: "Для массового табеля выбери объект или назови его в команде",
      }, 400);
    }
    if (isForeman && objectName !== assignedObject) {
      return json({ error: "Прораб может менять табель только своего объекта" }, 403);
    }

    const defaultShifts = defaultBulkShift(prompt);
    if (defaultShifts == null) {
      return json({ error: "Не понял значение смены для всех сотрудников" }, 400);
    }

    const { data: employeeRows, error: employeeError } = await client
      .from("employees")
      .select("id, fio, object_name")
      .eq("company_id", companyId)
      .eq("object_name", objectName)
      .is("archived_at", null)
      .order("fio");
    if (employeeError) throw employeeError;
    const employees = (employeeRows ?? []) as EmployeeRow[];
    if (employees.length === 0) {
      return json({ error: "На объекте нет активных сотрудников" }, 400);
    }

    const matchedEmployees = employees.filter((employee) => nameMatches(prompt, employee.fio));
    const overrides: Array<Record<string, unknown>> = [];
    for (const employee of matchedEmployees) {
      const shifts = shiftNearEmployee(prompt, employee);
      if (shifts == null || shifts === defaultShifts) continue;
      overrides.push({
        employee_id: employee.id,
        employee_name: employee.fio,
        shifts,
      });
    }

    const mentionedNameLikeTokens = tokens(prompt).filter((token) => token.length >= 4);
    if (/\b(?:кроме|исключая)\b/.test(normalized(prompt)) && overrides.length === 0 && mentionedNameLikeTokens.length > 0) {
      return json({ error: "Не смог однозначно определить исключение из табеля" }, 400);
    }

    const overrideHighlights = overrides.map((item) =>
      `${item.employee_name}: ${item.shifts} смены`
    );
    return json(resultWithAction({
      title: "Массовый табель подготовлен",
      summary:
        `${objectName}: ${employees.length} сотрудников → ${defaultShifts} смены` +
        (overrides.length > 0 ? `, исключений: ${overrides.length}.` : "."),
      highlights: [
        `Дата: ${date}`,
        `Основное значение: ${defaultShifts}`,
        `Сотрудников: ${employees.length}`,
        ...overrideHighlights,
      ],
      warnings: [
        "Табель изменится только после отдельного подтверждения на экране.",
      ],
      objectName,
      date,
      action: {
        id: crypto.randomUUID(),
        type: "bulk_timesheet_update",
        title: "Массовое изменение табеля",
        button_label: "Проверить массовый табель",
        confirmation_required: true,
        payload: {
          object_name: objectName,
          date,
          default_shifts: defaultShifts,
          affected_count: employees.length,
          overrides,
          source_prompt: prompt,
        },
      },
    }));
  } catch (error) {
    console.error("ai-global-command failed", error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
