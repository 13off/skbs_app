import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import { buildCandidateResponsible } from "./extended_actions.ts";
import {
  buildHrStageMove,
  buildProcurementStatus,
} from "./professional_actions.ts";
import { referenceWords, shiftValue } from "./reference_followup.ts";
import {
  clean,
  nameMatches,
  normalized,
  resultWithAction,
} from "./shared.ts";

type BuilderResult =
  | { body: Record<string, unknown>; status: number }
  | { error: string; status: number };

type EmployeeRow = {
  id: string;
  fio: string;
  position: string | null;
  object_name: string | null;
  object_id: string | null;
};

type CandidateRow = {
  id: string;
  full_name: string;
  object_id: string | null;
  responsible_user_id: string | null;
  source: string;
  external_user_id: string | null;
  external_chat_id: string | null;
  status: string;
  stage_id: string | null;
  ready_date: string | null;
};

type ProcurementRow = {
  id: string;
  title: string;
  object_id: string;
  object_name: string | null;
  status: string;
  priority: string;
  needed_by: string | null;
};

type ObjectRow = { id: string; name: string };
type PlannerDomain = "employees" | "candidates" | "procurement";
type CandidateDocType =
  | "passport_main"
  | "registration"
  | "snils"
  | "inn"
  | "policy";

type SelectionResult<T> = { selected?: T[]; error?: string };

const maxPlannedWrites = 12;
const requiredCandidateDocuments = new Set<CandidateDocType>([
  "passport_main",
  "registration",
  "snils",
  "inn",
  "policy",
]);

const ordinalRoots: Array<[string, number]> = [
  ["перв", 0],
  ["втор", 1],
  ["трет", 2],
  ["четверт", 3],
  ["пят", 4],
  ["шест", 5],
  ["седьм", 6],
  ["восьм", 7],
  ["девят", 8],
  ["десят", 9],
  ["последн", -1],
];

const countWords = new Map<string, number>([
  ["два", 2], ["две", 2], ["двух", 2], ["двум", 2], ["двоим", 2],
  ["три", 3], ["трех", 3], ["троим", 3],
  ["четыре", 4], ["четырех", 4], ["четырем", 4], ["четверым", 4],
  ["пять", 5], ["пяти", 5], ["пятерым", 5],
  ["шесть", 6], ["шести", 6],
  ["семь", 7], ["семи", 7],
  ["восемь", 8], ["восьми", 8],
  ["девять", 9], ["девяти", 9],
  ["десять", 10], ["десяти", 10],
]);

function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

function hrRole(role: string) {
  return managerRole(role) || role === "hr";
}

function procurementRole(role: string) {
  return managerRole(role) || role === "procurement";
}

function plannerDomain(prompt: string): PlannerDomain | null {
  const value = normalized(prompt);
  if (/(?:кандидат|соискател|резюме|вылет|документ)/.test(value)) {
    return "candidates";
  }
  if (/(?:заявк|снабжен|закуп|поставк)/.test(value)) return "procurement";
  if (/(?:сотрудник|работник|бригада|табел|смен|не\s+выш|присутств)/.test(value)) {
    return "employees";
  }
  return null;
}

function actionMarkerIndex(value: string, domain: PlannerDomain): number {
  const roots = domain === "candidates"
    ? ["назнач", "закреп", "перевед", "перемест", "перекин", "напиши", "отправ", "сообщ", "черк"]
    : domain === "procurement"
    ? ["перевед", "провед", "отмет", "согласу", "заказ", "достав", "отмен", "следующ"]
    : ["постав", "простав", "отмет", "исправ", "поправ", "измени", "сдел"];
  let best = -1;
  for (const root of roots) {
    const index = value.indexOf(root);
    if (index >= 0 && (best < 0 || index < best)) best = index;
  }
  return best;
}

function selectorClause(prompt: string, domain: PlannerDomain): string {
  const value = normalized(prompt);
  const index = actionMarkerIndex(value, domain);
  return index < 0 ? value : value.slice(0, index).trim();
}

export function multiStepPlanIntent(prompt: string): boolean {
  const domain = plannerDomain(prompt);
  if (domain == null) return false;
  const value = normalized(prompt);
  if (actionMarkerIndex(value, domain) < 0) return false;

  const select = selectorClause(prompt, domain);
  const selectionVerb = /(?:найд|найти|покаж|выбер|выбери|отбер|отобрать|кто|котор|тех|все|всех|без\s+|не\s+выш|просроч|сроч|вылет)/.test(select);
  const filter = domain === "employees"
    ? /(?:не\s+выш|не\s+явил|отсутств|прогул|присутств|на\s+работ|должност|бетон|арматур|прораб|мастер)/.test(select)
    : domain === "candidates"
    ? /(?:без\s+ответствен|не\s+назначен|документ|без\s+паспорт|без\s+регистрац|без\s+снилс|без\s+инн|без\s+полис|не\s+ответ|без\s+ответ|вылет|рейс|готов)/.test(select)
    : /(?:просроч|сроч|urgent|высок|submitted|approved|purchasing|ordered|delivery|достав|согласован|заказан)/.test(select);
  return selectionVerb && filter;
}

function ordinalForWord(word: string): number | null {
  for (const [root, index] of ordinalRoots) {
    if (word.startsWith(root)) return index;
  }
  return null;
}

function ordinalIndexes(prompt: string): number[] {
  const values: number[] = [];
  for (const word of referenceWords(prompt)) {
    const ordinal = ordinalForWord(word);
    if (ordinal != null) values.push(ordinal);
  }
  return values;
}

function groupCount(prompt: string): number | null {
  for (const word of referenceWords(prompt)) {
    const named = countWords.get(word);
    if (named != null) return named;
    if (/^\d{1,2}$/.test(word)) {
      const parsed = Number(word);
      if (Number.isInteger(parsed) && parsed >= 2 && parsed <= maxPlannedWrites) {
        return parsed;
      }
    }
  }
  return null;
}

function ordinalAfter(words: string[], marker: string): number[] {
  const markerIndex = words.indexOf(marker);
  if (markerIndex < 0) return [];
  const result: number[] = [];
  for (let index = markerIndex + 1; index < words.length; index += 1) {
    const ordinal = ordinalForWord(words[index]);
    if (ordinal != null) result.push(ordinal);
  }
  return result;
}

function indexFromOrdinal(raw: number, length: number): number {
  return raw < 0 ? length - 1 : raw;
}

function selectPlannedRows<T>(prompt: string, rows: T[]): SelectionResult<T> {
  if (rows.length === 0) return { selected: [] };
  const words = referenceWords(prompt);
  const except = ordinalAfter(words, "кроме");
  if (except.length > 0) {
    const excluded = new Set<number>();
    for (const raw of except) {
      const index = indexFromOrdinal(raw, rows.length);
      if (index < 0 || index >= rows.length) {
        return { error: `В найденной группе только ${rows.length} позиций: исключение выходит за пределы списка.` };
      }
      excluded.add(index);
    }
    const selected = rows.filter((_, index) => !excluded.has(index));
    return selected.length > maxPlannedWrites
      ? { error: `После исключения остаётся ${selected.length}. Для одной голосовой операции максимум ${maxPlannedWrites}; сузь группу.` }
      : { selected };
  }

  const count = groupCount(prompt);
  if (count != null) {
    if (count > rows.length) {
      return { error: `Найдено только ${rows.length}, а запрошено ${count}.` };
    }
    const first = words.some((word) => word.startsWith("перв"));
    const last = words.some((word) => word.startsWith("последн"));
    if (first) return { selected: rows.slice(0, count) };
    if (last) return { selected: rows.slice(rows.length - count) };
  }

  const ordinals = ordinalIndexes(prompt);
  if (ordinals.length > 0 && count == null) {
    const indexes = [...new Set(ordinals.map((raw) => indexFromOrdinal(raw, rows.length)))];
    if (indexes.some((index) => index < 0 || index >= rows.length)) {
      return { error: `В найденной группе только ${rows.length} позиций: одна из названных позиций отсутствует.` };
    }
    return { selected: indexes.map((index) => rows[index]) };
  }

  if (rows.length > maxPlannedWrites) {
    return {
      error: `Найдено ${rows.length}. Для безопасной голосовой операции максимум ${maxPlannedWrites}. Скажи, например, «первым пяти» или добавь фильтр.`,
    };
  }
  return { selected: rows };
}

async function loadObjects(client: SupabaseClient, companyId: string): Promise<ObjectRow[]> {
  const { data, error } = await client
    .from("objects")
    .select("id, name")
    .eq("company_id", companyId)
    .eq("is_active", true)
    .order("name")
    .limit(300);
  if (error) throw error;
  return (data ?? []) as ObjectRow[];
}

async function resolveObjectScope({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  selector,
  required = false,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  selector: string;
  required?: boolean;
}): Promise<{ id: string; name: string } | { error: string; status: number } | null> {
  const objects = await loadObjects(client, companyId);
  if (role === "foreman") {
    const matches = objects.filter((item) => normalized(item.name) === normalized(assignedObject));
    return matches.length === 1
      ? matches[0]
      : { error: "Не удалось подтвердить объект прораба", status: 403 };
  }

  const explicit = clean(requestedObject, 180);
  if (explicit) {
    const matches = objects.filter((item) => normalized(item.name) === normalized(explicit));
    if (matches.length === 1) return matches[0];
  }

  const promptMatches = objects.filter((item) => nameMatches(selector, item.name));
  if (promptMatches.length === 1) return promptMatches[0];
  if (promptMatches.length > 1) {
    return {
      error: `Нашёл несколько объектов: ${promptMatches.slice(0, 5).map((item) => item.name).join(", ")}. Уточни объект.`,
      status: 409,
    };
  }
  if (required && objects.length > 1) {
    return { error: "Для этой операции назови объект", status: 409 };
  }
  return null;
}

function planBody({
  domain,
  selectorSummary,
  matchedCount,
  selectedCount,
  date,
  title,
  summary,
  labels,
  actions,
  objectName = "",
}: {
  domain: PlannerDomain;
  selectorSummary: string;
  matchedCount: number;
  selectedCount: number;
  date: string;
  title: string;
  summary: string;
  labels: string[];
  actions: Record<string, unknown>[];
  objectName?: string;
}) {
  const action = actions.length === 1
    ? actions[0]
    : {
      id: crypto.randomUUID(),
      type: "voice_compound_batch",
      title: `Выполнить план из ${actions.length} действий`,
      button_label: `Проверить ${actions.length} действий`,
      confirmation_required: true,
      payload: {
        actions,
        planner_version: 15,
      },
    };
  const body = resultWithAction({
    title,
    summary,
    highlights: labels.slice(0, 12),
    warnings: [
      actions.length === 1
        ? "План ничего не меняет до штатного подтверждения действия."
        : "План подготовлен. Каждый шаг по-прежнему проходит штатное подтверждение, проверку роли и ИИ-аудит.",
    ],
    objectName,
    date,
    action,
  });
  return {
    ...body,
    plan: {
      version: 15,
      source: "deterministic_tool_planner",
      domain,
      selector_summary: clean(selectorSummary, 500),
      matched_count: matchedCount,
      selected_count: selectedCount,
    },
  };
}

function timesheetAction(employee: EmployeeRow, shifts: number, date: string) {
  return {
    id: crypto.randomUUID(),
    type: "prepare_timesheet_correction",
    title: "Корректировка табеля",
    button_label: "Проверить и применить",
    confirmation_required: true,
    payload: {
      employee_id: employee.id,
      employee_name: employee.fio,
      object_name: clean(employee.object_name, 180),
      date,
      shifts,
      source_prompt: "voice_multi_step_plan_v15",
    },
  };
}

async function buildEmployeePlan({
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
}): Promise<BuilderResult | null> {
  if (!managerRole(role) && role !== "foreman") {
    return { error: "Массовые операции с табелем недоступны текущей роли", status: 403 };
  }
  const shifts = shiftValue(prompt);
  if (shifts == null) return null;
  const selector = selectorClause(prompt, "employees");
  const absence = /(?:не\s+выш|не\s+явил|отсутств|прогул)/.test(selector);
  const presence = !absence && /(?:присутств|на\s+работ|вышл?и?\s+на\s+работ|вышел|вышли)/.test(selector);
  if (!absence && !presence) return null;

  const objectScope = await resolveObjectScope({
    client,
    companyId,
    role,
    assignedObject,
    requestedObject,
    selector,
  });
  if (objectScope && "error" in objectScope) return objectScope;

  let employeesQuery = client
    .from("employees")
    .select("id, fio, position, object_name, object_id")
    .eq("company_id", companyId)
    .eq("is_active", true)
    .is("archived_at", null)
    .order("fio")
    .limit(500);
  let attendanceQuery = client
    .from("attendance")
    .select("employee_id, shifts")
    .eq("company_id", companyId)
    .eq("work_date", date)
    .is("deleted_at", null)
    .limit(1000);
  if (objectScope) {
    employeesQuery = employeesQuery.eq("object_id", objectScope.id);
    attendanceQuery = attendanceQuery.eq("object_id", objectScope.id);
  }
  const [employeesResult, attendanceResult] = await Promise.all([
    employeesQuery,
    attendanceQuery,
  ]);
  if (employeesResult.error) throw employeesResult.error;
  if (attendanceResult.error) throw attendanceResult.error;

  const attendanceByEmployee = new Map<string, number>();
  for (const row of attendanceResult.data ?? []) {
    const employeeId = clean((row as any).employee_id, 80);
    const current = attendanceByEmployee.get(employeeId) ?? 0;
    const value = Number((row as any).shifts ?? 0);
    if (Number.isFinite(value)) attendanceByEmployee.set(employeeId, current + value);
  }

  let employees = (employeesResult.data ?? []) as EmployeeRow[];
  const positions = [...new Set(employees.map((row) => clean(row.position, 120)).filter(Boolean))];
  const mentionedPositions = positions.filter((position) => nameMatches(selector, position));
  if (mentionedPositions.length === 1) {
    const expected = normalized(mentionedPositions[0]);
    employees = employees.filter((row) => normalized(row.position) === expected);
  }
  employees = employees.filter((row) => {
    const worked = (attendanceByEmployee.get(row.id) ?? 0) > 0;
    return absence ? !worked : worked;
  });

  const selection = selectPlannedRows(prompt, employees);
  if (!selection.selected) {
    return { error: selection.error ?? "Не понял, какую часть найденной группы выбрать", status: 409 };
  }
  if (selection.selected.length === 0) {
    return {
      error: absence
        ? `За ${date} не нашёл сотрудников без положительной отметки табеля по заданным условиям.`
        : `За ${date} не нашёл присутствующих сотрудников по заданным условиям.`,
      status: 400,
    };
  }

  const actions = selection.selected.map((employee) => timesheetAction(employee, shifts, date));
  const objectName = objectScope?.name ?? "";
  return {
    body: planBody({
      domain: "employees",
      selectorSummary: selector,
      matchedCount: employees.length,
      selectedCount: selection.selected.length,
      date,
      title: "План по табелю подготовлен",
      summary: `Нашёл ${employees.length}; в действие вошло ${selection.selected.length}. Значение: ${shifts} смены за ${date}.`,
      labels: selection.selected.map((row) => `${row.fio} → ${shifts}`),
      actions,
      objectName,
    }),
    status: 200,
  };
}

function missingDocumentType(selector: string): CandidateDocType | null {
  if (/(?:без\s+паспорт|нет\s+паспорт)/.test(selector)) return "passport_main";
  if (/(?:без\s+(?:пропис|регистрац)|нет\s+(?:пропис|регистрац))/.test(selector)) return "registration";
  if (/(?:без\s+снилс|нет\s+снилс)/.test(selector)) return "snils";
  if (/(?:без\s+инн|нет\s+инн)/.test(selector)) return "inn";
  if (/(?:без\s+полис|нет\s+полис)/.test(selector)) return "policy";
  return null;
}

function candidateMessageBody(prompt: string): string {
  const colon = prompt.match(/[:\-]\s*(.+)$/s)?.[1];
  if (colon?.trim()) return clean(colon, 4000);
  const what = prompt.match(/\bчто\s+(.+)$/is)?.[1];
  if (what?.trim()) return clean(what, 4000);
  const message = prompt.match(/\bсообщени\w*\s+(.+)$/is)?.[1];
  return clean(message, 4000);
}

function canMessageCandidate(row: CandidateRow): boolean {
  const source = clean(row.source, 30).toLowerCase();
  if (source === "telegram") return clean(row.external_chat_id, 120).length > 0;
  if (source === "max") return clean(row.external_user_id, 120).length > 0;
  return false;
}

function candidateMessageAction(row: CandidateRow, body: string) {
  return {
    id: crypto.randomUUID(),
    type: "send_candidate_message",
    title: `Отправить сообщение: ${row.full_name}`,
    button_label: "Проверить сообщение",
    confirmation_required: true,
    payload: {
      application_id: row.id,
      candidate_name: row.full_name,
      source: clean(row.source, 30).toLowerCase(),
      body,
      source_prompt: "voice_multi_step_plan_v15",
    },
  };
}

async function candidateDocuments(
  client: SupabaseClient,
  companyId: string,
  ids: string[],
): Promise<Map<string, Set<CandidateDocType>>> {
  const result = new Map<string, Set<CandidateDocType>>();
  if (ids.length === 0) return result;
  const { data, error } = await client
    .from("recruitment_documents")
    .select("application_id, document_type")
    .eq("company_id", companyId)
    .in("application_id", ids)
    .limit(5000);
  if (error) throw error;
  for (const row of data ?? []) {
    const applicationId = clean((row as any).application_id, 80);
    const type = clean((row as any).document_type, 40) as CandidateDocType;
    if (!requiredCandidateDocuments.has(type)) continue;
    const set = result.get(applicationId) ?? new Set<CandidateDocType>();
    set.add(type);
    result.set(applicationId, set);
  }
  return result;
}

async function unansweredCandidateIds(
  client: SupabaseClient,
  companyId: string,
  ids: string[],
): Promise<Set<string>> {
  if (ids.length === 0) return new Set<string>();
  const { data, error } = await client
    .from("recruitment_messages")
    .select("application_id, direction, created_at")
    .eq("company_id", companyId)
    .in("application_id", ids)
    .in("direction", ["inbound", "outbound"])
    .order("created_at", { ascending: true })
    .limit(10000);
  if (error) throw error;
  const latestInbound = new Map<string, number>();
  const latestOutbound = new Map<string, number>();
  for (const row of data ?? []) {
    const applicationId = clean((row as any).application_id, 80);
    const time = Date.parse(clean((row as any).created_at, 60));
    if (!Number.isFinite(time)) continue;
    const direction = clean((row as any).direction, 20);
    const target = direction === "inbound" ? latestInbound : latestOutbound;
    target.set(applicationId, Math.max(target.get(applicationId) ?? 0, time));
  }
  return new Set(ids.filter((id) => {
    const outbound = latestOutbound.get(id) ?? 0;
    const inbound = latestInbound.get(id) ?? 0;
    return outbound > 0 && outbound > inbound;
  }));
}

async function flightCandidateIds(
  client: SupabaseClient,
  companyId: string,
  ids: string[],
  date: string,
): Promise<Set<string>> {
  if (ids.length === 0) return new Set<string>();
  const start = `${date}T00:00:00.000Z`;
  const next = new Date(`${date}T00:00:00.000Z`);
  next.setUTCDate(next.getUTCDate() + 1);
  const { data, error } = await client
    .from("recruitment_flights")
    .select("application_id, departure_at, status")
    .eq("company_id", companyId)
    .in("application_id", ids)
    .gte("departure_at", start)
    .lt("departure_at", next.toISOString())
    .neq("status", "cancelled")
    .limit(1000);
  if (error) throw error;
  return new Set((data ?? []).map((row: any) => clean(row.application_id, 80)).filter(Boolean));
}

async function buildCandidatePlan({
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
}): Promise<BuilderResult | null> {
  if (!hrRole(role)) return { error: "Многошаговые HR-команды недоступны текущей роли", status: 403 };
  const selector = selectorClause(prompt, "candidates");
  const value = normalized(prompt);
  const actionAssign = /(?:назнач|закреп).*(?:ответствен)|(?:ответствен).*(?:назнач|закреп)/.test(value);
  const actionStage = /(?:перевед|перемест|перекин).*(?:этап|стади|билет|кандидат)|(?:этап|стади|билет).*(?:перевед|перемест|перекин)/.test(value);
  const actionMessage = /(?:напиши|отправ|сообщ|черк)/.test(value);
  if (!actionAssign && !actionStage && !actionMessage) return null;

  const objectScope = await resolveObjectScope({
    client,
    companyId,
    role,
    assignedObject: "",
    requestedObject,
    selector,
  });
  if (objectScope && "error" in objectScope) return objectScope;

  let query = client
    .from("recruitment_applications")
    .select("id, full_name, object_id, responsible_user_id, source, external_user_id, external_chat_id, status, stage_id, ready_date")
    .eq("company_id", companyId)
    .is("archived_at", null)
    .eq("is_test_record", false)
    .order("updated_at", { ascending: false })
    .limit(500);
  if (objectScope) query = query.eq("object_id", objectScope.id);
  const { data, error } = await query;
  if (error) throw error;
  let candidates = (data ?? []) as CandidateRow[];
  const ids = candidates.map((row) => row.id);

  const wantsNoResponsible = /(?:без\s+ответствен|не\s+назначен\w*\s+ответствен|нет\s+ответствен)/.test(selector);
  const specificMissing = missingDocumentType(selector);
  const wantsIncompleteDocs = /(?:неполн\w*\s+комплект|нет\s+полн\w*\s+комплект|не\s+хватает\s+документ|недоста\w*\s+документ)/.test(selector);
  const wantsNoDocs = /(?:без\s+документ|нет\s+документ)/.test(selector) && !wantsIncompleteDocs;
  const wantsUnanswered = /(?:без\s+ответ|не\s+ответ|не\s+отвеч|ждем\s+ответ|ждём\s+ответ)/.test(selector);
  const wantsFlight = /(?:вылет|вылета|рейс|улета)/.test(selector);

  if (wantsNoResponsible) {
    candidates = candidates.filter((row) => !clean(row.responsible_user_id, 80));
  }

  if (specificMissing || wantsIncompleteDocs || wantsNoDocs) {
    const docs = await candidateDocuments(client, companyId, ids);
    candidates = candidates.filter((row) => {
      const present = docs.get(row.id) ?? new Set<CandidateDocType>();
      if (specificMissing) return !present.has(specificMissing);
      if (wantsNoDocs) return present.size === 0;
      return [...requiredCandidateDocuments].some((type) => !present.has(type));
    });
  }

  if (wantsUnanswered) {
    const unanswered = await unansweredCandidateIds(client, companyId, ids);
    candidates = candidates.filter((row) => unanswered.has(row.id));
  }

  if (wantsFlight) {
    const flightIds = await flightCandidateIds(client, companyId, ids, date);
    candidates = candidates.filter((row) => flightIds.has(row.id));
  }

  const selection = selectPlannedRows(prompt, candidates);
  if (!selection.selected) {
    return { error: selection.error ?? "Не понял выбор внутри найденной группы кандидатов", status: 409 };
  }
  if (selection.selected.length === 0) {
    return { error: "По заданным условиям кандидатов не найдено", status: 400 };
  }

  const actions: Record<string, unknown>[] = [];
  const labels: string[] = [];
  if (actionMessage) {
    const body = candidateMessageBody(prompt);
    if (!body) return { error: "Скажи текст сообщения после двоеточия или после слова «что».", status: 400 };
    const unavailable = selection.selected.filter((row) => !canMessageCandidate(row));
    if (unavailable.length > 0) {
      return {
        error: `У части выбранных кандидатов нет подтверждённого Telegram/MAX-канала: ${unavailable.slice(0, 6).map((row) => row.full_name).join(", ")}. Сообщения не подготовлены.`,
        status: 409,
      };
    }
    for (const row of selection.selected) {
      actions.push(candidateMessageAction(row, body));
      labels.push(`${row.full_name} • ${row.source}`);
    }
  } else {
    for (const row of selection.selected) {
      const explicit = actionStage
        ? `${row.full_name}. ${prompt}. переведи кандидата на этап`
        : `${row.full_name}. ${prompt}. назначь ответственного кандидату`;
      const built = actionStage
        ? await buildHrStageMove({ client, companyId, role, prompt: explicit, date })
        : await buildCandidateResponsible({ client, companyId, role, prompt: explicit, date });
      if ("error" in built) return built;
      const action = (built.body as any).action;
      if (action && typeof action === "object") actions.push(action as Record<string, unknown>);
      labels.push(clean((built.body as any).summary, 300) || row.full_name);
    }
  }

  if (actions.length === 0) return { error: "План не смог подготовить ни одного HR-действия", status: 400 };
  return {
    body: planBody({
      domain: "candidates",
      selectorSummary: selector,
      matchedCount: candidates.length,
      selectedCount: selection.selected.length,
      date,
      title: "Многошаговый HR-план подготовлен",
      summary: `По условиям найдено ${candidates.length}; в действие вошло ${selection.selected.length}.`,
      labels,
      actions,
      objectName: objectScope?.name ?? "",
    }),
    status: 200,
  };
}

function procurementSelectorStatus(selector: string): string | null {
  if (/(?:черновик|draft)/.test(selector)) return "draft";
  if (/(?:подан|отправлен|submitted)/.test(selector)) return "submitted";
  if (/(?:согласован|одобрен|approved)/.test(selector)) return "approved";
  if (/(?:закупа|в\s+закупк|purchasing)/.test(selector)) return "purchasing";
  if (/(?:заказан|ordered)/.test(selector)) return "ordered";
  if (/(?:в\s+доставк|едет|in\s+delivery)/.test(selector)) return "in_delivery";
  return null;
}

async function buildProcurementPlan({
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
}): Promise<BuilderResult | null> {
  if (!procurementRole(role)) return { error: "Многошаговые команды снабжения недоступны текущей роли", status: 403 };
  const selector = selectorClause(prompt, "procurement");
  const value = normalized(prompt);
  if (!/(?:перевед|провед|отмет|согласу|заказ|достав|отмен|следующ)/.test(value)) return null;

  const objectScope = await resolveObjectScope({
    client,
    companyId,
    role,
    assignedObject: "",
    requestedObject,
    selector,
  });
  if (objectScope && "error" in objectScope) return objectScope;

  let query = client
    .from("procurement_requests")
    .select("id, title, object_id, object_name, status, priority, needed_by")
    .eq("company_id", companyId)
    .not("status", "in", "(delivered,canceled)")
    .order("needed_by", { ascending: true, nullsFirst: false })
    .order("updated_at", { ascending: false })
    .limit(500);
  if (objectScope) query = query.eq("object_id", objectScope.id);
  const { data, error } = await query;
  if (error) throw error;
  let requests = (data ?? []) as ProcurementRow[];

  if (/(?:просроч)/.test(selector)) {
    requests = requests.filter((row) => clean(row.needed_by, 10) && clean(row.needed_by, 10) < date);
  }
  if (/(?:сроч|urgent)/.test(selector)) {
    requests = requests.filter((row) => row.priority === "urgent");
  } else if (/(?:высок\w*\s+приоритет)/.test(selector)) {
    requests = requests.filter((row) => row.priority === "high");
  }
  const sourceStatus = procurementSelectorStatus(selector);
  if (sourceStatus) requests = requests.filter((row) => row.status === sourceStatus);

  const selection = selectPlannedRows(prompt, requests);
  if (!selection.selected) {
    return { error: selection.error ?? "Не понял выбор внутри найденных заявок", status: 409 };
  }
  if (selection.selected.length === 0) {
    return { error: "По заданным условиям заявок снабжения не найдено", status: 400 };
  }

  const actions: Record<string, unknown>[] = [];
  const labels: string[] = [];
  for (const row of selection.selected) {
    const built = await buildProcurementStatus({
      client,
      companyId,
      role,
      prompt: `${row.title}. ${prompt}. заявка снабжения`,
      date,
      requestedObject: clean(row.object_name, 180),
    });
    if ("error" in built) return built;
    const action = (built.body as any).action;
    if (action && typeof action === "object") actions.push(action as Record<string, unknown>);
    labels.push(clean((built.body as any).summary, 300) || row.title);
  }

  if (actions.length === 0) return { error: "План не смог подготовить действия снабжения", status: 400 };
  return {
    body: planBody({
      domain: "procurement",
      selectorSummary: selector,
      matchedCount: requests.length,
      selectedCount: selection.selected.length,
      date,
      title: "План снабжения подготовлен",
      summary: `По условиям найдено ${requests.length}; в действие вошло ${selection.selected.length}.`,
      labels,
      actions,
      objectName: objectScope?.name ?? "",
    }),
    status: 200,
  };
}

export async function buildMultiStepVoicePlan({
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
}): Promise<BuilderResult | null> {
  if (!multiStepPlanIntent(prompt)) return null;
  const domain = plannerDomain(prompt);
  if (domain === "employees") {
    return await buildEmployeePlan({
      client,
      companyId,
      role,
      assignedObject,
      requestedObject,
      prompt,
      date,
    });
  }
  if (domain === "candidates") {
    return await buildCandidatePlan({
      client,
      companyId,
      role,
      requestedObject,
      prompt,
      date,
    });
  }
  if (domain === "procurement") {
    return await buildProcurementPlan({
      client,
      companyId,
      role,
      requestedObject,
      prompt,
      date,
    });
  }
  return null;
}
