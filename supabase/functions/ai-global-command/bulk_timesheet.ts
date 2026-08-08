import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import {
  clean,
  type EmployeeRow,
  nameMatches,
  nameTokens,
  normalized,
  type ObjectRow,
  resultWithAction,
  tokens,
} from "./shared.ts";

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

export function bulkTimesheetIntent(prompt: string): boolean {
  const value = normalized(prompt);
  const hasEveryone = /\b(?:всем|всех|каждому|все)\b/.test(value);
  const hasWrite = /(?:постав|простав|отмет|заполн|табел|смен)/.test(value);
  return hasEveryone && hasWrite && defaultBulkShift(value) != null;
}

function isManager(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

export async function buildBulkTimesheetResult({
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
  const isForeman = role === "foreman";
  if (!isManager(role) && !isForeman) {
    return {
      error: "Массовый табель доступен руководителю или прорабу",
      status: 403,
    };
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
    return {
      error: "Для массового табеля выбери объект или назови его в команде",
      status: 400,
    };
  }
  if (isForeman && objectName !== assignedObject) {
    return {
      error: "Прораб может менять табель только своего объекта",
      status: 403,
    };
  }

  const defaultShifts = defaultBulkShift(prompt);
  if (defaultShifts == null) {
    return {
      error: "Не понял значение смены для всех сотрудников",
      status: 400,
    };
  }

  const { data: employeeRows, error: employeeError } = await client
    .from("employees")
    .select("id, fio, object_name")
    .eq("company_id", companyId)
    .eq("object_name", objectName)
    .eq("is_active", true)
    .is("archived_at", null)
    .order("fio");
  if (employeeError) throw employeeError;
  const employees = (employeeRows ?? []) as EmployeeRow[];
  if (employees.length === 0) {
    return { error: "На объекте нет активных сотрудников", status: 400 };
  }

  const matchedEmployees = employees.filter((employee) =>
    nameMatches(prompt, employee.fio)
  );
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

  if (/\b(?:кроме|исключая)\b/.test(normalized(prompt)) && overrides.length === 0) {
    const likelyNames = tokens(prompt).filter((token) => token.length >= 4);
    if (likelyNames.length > 0) {
      return {
        error: "Не смог однозначно определить исключение из табеля",
        status: 400,
      };
    }
  }

  const overrideHighlights = overrides.map((item) =>
    `${item.employee_name}: ${item.shifts} смены`
  );
  return {
    body: resultWithAction({
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
    }),
    status: 200,
  };
}
