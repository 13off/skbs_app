import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.5";

import type { GlobalVoiceConversationContext } from "./conversation_context.ts";
import { buildCandidateResponsible } from "./extended_actions.ts";
import {
  buildHrStageMove,
  buildProcurementStatus,
} from "./professional_actions.ts";
import { referenceWords, shiftValue } from "./reference_followup.ts";
import { clean, normalized, resultWithAction } from "./shared.ts";

type ReferenceEntity = {
  id: string;
  label: string;
  objectName: string;
};

type ReferenceSet = {
  type: "employee" | "candidate" | "procurement";
  entities: ReferenceEntity[];
};

type BuilderResult =
  | { body: Record<string, unknown>; status: number }
  | { error: string; status: number };

const pluralPronouns = new Set([
  "им",
  "их",
  "ими",
  "этим",
  "этих",
  "эти",
  "этими",
]);
const ordinalRoots: Array<[string, number]> = [
  ["перв", 0],
  ["втор", 1],
  ["трет", 2],
  ["четверт", 3],
  ["пят", 4],
  ["последн", -1],
];
const countWords = new Map<string, number>([
  ["два", 2],
  ["две", 2],
  ["двух", 2],
  ["двум", 2],
  ["двоим", 2],
  ["три", 3],
  ["трех", 3],
  ["троим", 3],
  ["четыре", 4],
  ["четырех", 4],
  ["четырем", 4],
  ["четверым", 4],
  ["пять", 5],
  ["пяти", 5],
  ["пятерым", 5],
]);

function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

function ordinalForWord(word: string): number | null {
  for (const [root, index] of ordinalRoots) {
    if (word.startsWith(root)) return index;
  }
  return null;
}

function ordinalIndexes(prompt: string): number[] {
  return referenceWords(prompt)
    .map(ordinalForWord)
    .filter((value): value is number => value != null);
}

function ordinalAfter(words: string[], marker: string): number | null {
  const markerIndex = words.indexOf(marker);
  if (markerIndex < 0) return null;
  for (let index = markerIndex + 1; index < words.length; index += 1) {
    const ordinal = ordinalForWord(words[index]);
    if (ordinal != null) return ordinal;
  }
  return null;
}

function groupCount(prompt: string): number | null {
  for (const word of referenceWords(prompt)) {
    const named = countWords.get(word);
    if (named != null) return named;
    if (/^\d{1,2}$/.test(word)) {
      const parsed = Number(word);
      if (Number.isInteger(parsed) && parsed >= 2 && parsed <= 10) return parsed;
    }
  }
  return null;
}

function pluralReference(prompt: string): boolean {
  return referenceWords(prompt).some((word) => pluralPronouns.has(word));
}

function sameAsYesterdayIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:сдел|постав|простав|отмет|заполн|скопир|повтор)/.test(value) &&
    /(?:как\s+вчера|как\s+(?:в\s+)?(?:предыдущ\w*|прошл\w*)\s+день)/.test(value);
}

function groupReferenceIntent(prompt: string): boolean {
  const words = referenceWords(prompt);
  const ordinals = ordinalIndexes(prompt);
  const count = groupCount(prompt);
  if (sameAsYesterdayIntent(prompt) && pluralReference(prompt)) return true;
  if (words.includes("по") && ordinals.length >= 2) return true;
  if (words.includes("кроме") && ordinalAfter(words, "кроме") != null) return true;
  if (count == null) return false;
  return pluralReference(prompt) ||
    words.some((word) => word.startsWith("перв") || word.startsWith("последн"));
}

function selectGroup(
  prompt: string,
  entities: ReferenceEntity[],
): { entities?: ReferenceEntity[]; error?: string } {
  if (entities.length === 0) {
    return { error: "Предыдущий список уже пуст или изменился. Повтори исходный запрос." };
  }

  const words = referenceWords(prompt);
  const ordinals = ordinalIndexes(prompt);
  if (words.includes("по") && ordinals.length >= 2) {
    const start = ordinals[0] < 0 ? entities.length - 1 : ordinals[0];
    const end = ordinals[1] < 0 ? entities.length - 1 : ordinals[1];
    if (start < 0 || end < 0 || start >= entities.length || end >= entities.length) {
      return { error: `В предыдущем списке только ${entities.length}. Диапазон выходит за его пределы.` };
    }
    if (start > end) {
      return { error: "Диапазон нужно назвать от более ранней позиции к более поздней." };
    }
    return { entities: entities.slice(start, end + 1) };
  }

  const excluded = ordinalAfter(words, "кроме");
  if (excluded != null) {
    const index = excluded < 0 ? entities.length - 1 : excluded;
    if (index < 0 || index >= entities.length) {
      return { error: `В предыдущем списке только ${entities.length}. Не смог определить исключение.` };
    }
    const remaining = entities.filter((_, itemIndex) => itemIndex !== index);
    if (remaining.length === 0) return { error: "После исключения в списке никого не осталось." };
    if (remaining.length > 30) {
      return { error: "После исключения группа всё ещё слишком большая для голосового массового действия." };
    }
    return { entities: remaining };
  }

  if (sameAsYesterdayIntent(prompt) && pluralReference(prompt)) {
    if (entities.length > 30) {
      return { error: "Группа слишком большая. Назови более узкую часть предыдущего списка." };
    }
    return { entities };
  }

  const count = groupCount(prompt);
  if (count == null) return { error: "Не понял размер группы из предыдущего списка." };
  if (count > entities.length) {
    return { error: `В предыдущем списке только ${entities.length}, а запрошено ${count}.` };
  }

  if (words.some((word) => word.startsWith("перв"))) {
    return { entities: entities.slice(0, count) };
  }
  if (words.some((word) => word.startsWith("последн"))) {
    return { entities: entities.slice(entities.length - count) };
  }
  if (pluralReference(prompt)) {
    if (entities.length === count) return { entities };
    return {
      error:
        `В предыдущем результате ${entities.length} записей. Фраза про ${count} человек неоднозначна: скажи «первым ${count}» или «последним ${count}».`,
    };
  }
  return { error: "Не понял, какую часть предыдущего списка выбрать." };
}

async function loadEmployees({
  client,
  companyId,
  role,
  assignedObject,
  context,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  context: GlobalVoiceConversationContext;
}): Promise<ReferenceSet> {
  let objectName = clean(context.objectName, 180);
  if (role === "foreman") objectName = assignedObject;
  let query = client
    .from("employees")
    .select("id, fio, object_name")
    .eq("company_id", companyId)
    .eq("is_active", true)
    .is("archived_at", null)
    .order("fio")
    .limit(20);
  if (objectName) query = query.eq("object_name", objectName);
  const { data, error } = await query;
  if (error) throw error;
  return {
    type: "employee",
    entities: (data ?? []).map((row: any) => ({
      id: clean(row.id, 80),
      label: clean(row.fio, 180),
      objectName: clean(row.object_name, 180),
    })),
  };
}

async function loadAbsenceEmployees({
  client,
  companyId,
  role,
  assignedObject,
  context,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  context: GlobalVoiceConversationContext;
}): Promise<ReferenceSet> {
  let objectName = clean(context.objectName, 180);
  if (role === "foreman") objectName = assignedObject;
  const date = /^20\d{2}-\d{2}-\d{2}$/.test(context.date) ? context.date : "";
  if (!date) return { type: "employee", entities: [] };

  let employeesQuery: any = client
    .from("employees")
    .select("id, fio, object_name")
    .eq("company_id", companyId)
    .eq("is_active", true)
    .is("archived_at", null)
    .order("fio");
  let attendanceQuery: any = client
    .from("attendance")
    .select("employee_id, shifts, object_name")
    .eq("company_id", companyId)
    .eq("work_date", date);
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

  const positive = new Set<string>();
  for (const row of attendanceResult.data ?? []) {
    const shifts = Number((row as any).shifts ?? 0);
    if (Number.isFinite(shifts) && shifts > 0) {
      positive.add(clean((row as any).employee_id, 80));
    }
  }
  return {
    type: "employee",
    entities: (employeesResult.data ?? [])
      .filter((row: any) => !positive.has(clean(row.id, 80)))
      .slice(0, 30)
      .map((row: any) => ({
        id: clean(row.id, 80),
        label: clean(row.fio, 180),
        objectName: clean(row.object_name, 180),
      })),
  };
}

async function loadCandidates({
  client,
  companyId,
}: {
  client: SupabaseClient;
  companyId: string;
}): Promise<ReferenceSet> {
  const { data, error } = await client
    .from("recruitment_applications")
    .select("id, full_name")
    .eq("company_id", companyId)
    .is("archived_at", null)
    .order("updated_at", { ascending: false })
    .limit(20);
  if (error) throw error;
  return {
    type: "candidate",
    entities: (data ?? []).map((row: any) => ({
      id: clean(row.id, 80),
      label: clean(row.full_name, 180),
      objectName: "",
    })),
  };
}

async function loadProcurement({
  client,
  companyId,
  context,
}: {
  client: SupabaseClient;
  companyId: string;
  context: GlobalVoiceConversationContext;
}): Promise<ReferenceSet> {
  let query = client
    .from("procurement_requests")
    .select("id, title, object_name")
    .eq("company_id", companyId)
    .not("status", "in", "(delivered,canceled)")
    .order("updated_at", { ascending: false })
    .limit(12);
  if (context.objectName) query = query.eq("object_name", context.objectName);
  const { data, error } = await query;
  if (error) throw error;
  return {
    type: "procurement",
    entities: (data ?? []).map((row: any) => ({
      id: clean(row.id, 80),
      label: clean(row.title, 220),
      objectName: clean(row.object_name, 180),
    })),
  };
}

async function loadReferenceSet(args: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  context: GlobalVoiceConversationContext;
}): Promise<ReferenceSet | null> {
  const { context, role } = args;
  if (context.topic === "absence_today") {
    if (!managerRole(role) && role !== "foreman") return null;
    return await loadAbsenceEmployees(args);
  }
  if (context.queryMode !== "list") return null;
  if (context.topic === "employees") {
    if (!managerRole(role) && role !== "foreman" && role !== "hr") return null;
    return await loadEmployees(args);
  }
  if (context.topic === "candidates") {
    if (!managerRole(role) && role !== "hr") return null;
    return await loadCandidates(args);
  }
  if (context.topic === "procurement") {
    if (!managerRole(role) && role !== "procurement") return null;
    return await loadProcurement(args);
  }
  return null;
}

function hasExplicitDate(prompt: string): boolean {
  return /(?:сегодня|завтра|послезавтра|вчера|(?:^|\s)20\d{2}-\d{1,2}-\d{1,2}(?=\s|$)|(?:^|\s)\d{1,2}[./]\d{1,2}(?:[./]20\d{2})?(?=\s|$))/i.test(prompt);
}

function hasExplicitTargetDate(prompt: string): boolean {
  const value = normalized(prompt)
    .replace(/как\s+вчера/g, " ")
    .replace(/как\s+(?:в\s+)?(?:предыдущ\w*|прошл\w*)\s+день/g, " ");
  return hasExplicitDate(value);
}

function previousIsoDate(value: string): string {
  const match = /^(20\d{2})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return "";
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  if (Number.isNaN(date.getTime())) return "";
  date.setUTCDate(date.getUTCDate() - 1);
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}-${String(date.getUTCDate()).padStart(2, "0")}`;
}

function timesheetAction(
  entity: ReferenceEntity,
  shifts: number,
  date: string,
  sourceDate = "",
) {
  return {
    id: crypto.randomUUID(),
    type: "prepare_timesheet_correction",
    title: "Корректировка табеля",
    button_label: "Проверить и применить",
    confirmation_required: true,
    payload: {
      employee_id: entity.id,
      employee_name: entity.label,
      object_name: entity.objectName,
      date,
      shifts,
      source_prompt: sourceDate
        ? "voice_group_reference_copy_previous_day"
        : "voice_group_reference_followup",
      source_date: sourceDate,
    },
  };
}

function compoundBody({
  title,
  summary,
  actions,
  labels,
  date,
}: {
  title: string;
  summary: string;
  actions: Record<string, unknown>[];
  labels: string[];
  date: string;
}) {
  if (actions.length === 1) {
    return resultWithAction({
      title,
      summary,
      highlights: labels,
      warnings: ["Изменение выполнится только после штатного подтверждения."],
      date,
      action: actions[0],
    });
  }
  return resultWithAction({
    title,
    summary,
    highlights: labels,
    warnings: ["Это пакет действий. Каждый шаг проходит обычную проверку, роли и подтверждение."],
    date,
    action: {
      id: crypto.randomUUID(),
      type: "voice_compound_batch",
      title: `Выполнить ${actions.length} действий по очереди`,
      button_label: `Проверить ${actions.length} действий`,
      confirmation_required: true,
      payload: { actions, source_prompts: labels },
    },
  });
}

async function buildCandidateBatch({
  client,
  companyId,
  role,
  date,
  prompt,
  selected,
  stage,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  date: string;
  prompt: string;
  selected: ReferenceEntity[];
  stage: boolean;
}): Promise<BuilderResult> {
  const actions: Record<string, unknown>[] = [];
  const labels: string[] = [];
  for (const entity of selected) {
    const explicit = stage
      ? `${entity.label}. ${prompt}. переведи кандидата на этап`
      : `${entity.label}. ${prompt}. назначь ответственного кандидату`;
    const result = stage
      ? await buildHrStageMove({ client, companyId, role, prompt: explicit, date })
      : await buildCandidateResponsible({ client, companyId, role, prompt: explicit, date });
    if ("error" in result) return result;
    const action = (result.body as any).action;
    if (action && typeof action === "object") actions.push(action);
    labels.push((result.body as any).summary ?? entity.label);
  }
  if (actions.length === 0) {
    return { error: "Не удалось подготовить действия для выбранной группы кандидатов", status: 400 };
  }
  return {
    body: compoundBody({
      title: stage ? "Групповой переход кандидатов подготовлен" : "Групповое назначение подготовлено",
      summary: `Подготовлено действий: ${actions.length}.`,
      actions,
      labels,
      date,
    }),
    status: 200,
  };
}

async function buildProcurementBatch({
  client,
  companyId,
  role,
  date,
  prompt,
  selected,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  date: string;
  prompt: string;
  selected: ReferenceEntity[];
}): Promise<BuilderResult> {
  const actions: Record<string, unknown>[] = [];
  const labels: string[] = [];
  for (const entity of selected) {
    const result = await buildProcurementStatus({
      client,
      companyId,
      role,
      prompt: `${entity.label}. ${prompt}. заявка снабжения`,
      date,
      requestedObject: entity.objectName,
    });
    if ("error" in result) return result;
    const action = (result.body as any).action;
    if (action && typeof action === "object") actions.push(action);
    labels.push((result.body as any).summary ?? entity.label);
  }
  if (actions.length === 0) {
    return { error: "Не удалось подготовить действия для выбранных заявок", status: 400 };
  }
  return {
    body: compoundBody({
      title: "Групповые статусы снабжения подготовлены",
      summary: `Подготовлено действий: ${actions.length}.`,
      actions,
      labels,
      date,
    }),
    status: 200,
  };
}

async function copyPreviousAttendance({
  client,
  companyId,
  selected,
  targetDate,
  conversationDate,
}: {
  client: SupabaseClient;
  companyId: string;
  selected: ReferenceEntity[];
  targetDate: string;
  conversationDate: string;
}): Promise<BuilderResult> {
  const sourceAnchor = /^20\d{2}-\d{2}-\d{2}$/.test(conversationDate)
    ? conversationDate
    : targetDate;
  const sourceDate = previousIsoDate(sourceAnchor);
  if (!sourceDate) {
    return { error: "Не смог определить предыдущий день для копирования табеля", status: 400 };
  }

  const { data, error } = await client
    .from("attendance")
    .select("employee_id, shifts, object_name")
    .eq("company_id", companyId)
    .eq("work_date", sourceDate)
    .in("employee_id", selected.map((entity) => entity.id));
  if (error) throw error;

  const rowsByEmployee = new Map<string, Array<Record<string, unknown>>>();
  for (const raw of data ?? []) {
    const row = raw as Record<string, unknown>;
    const id = clean(row.employee_id, 80);
    const rows = rowsByEmployee.get(id) ?? [];
    rows.push(row);
    rowsByEmployee.set(id, rows);
  }

  const prepared: Array<{ entity: ReferenceEntity; shifts: number }> = [];
  const unresolved: string[] = [];
  for (const entity of selected) {
    const rows = rowsByEmployee.get(entity.id) ?? [];
    const sameObject = entity.objectName
      ? rows.filter((row) => clean(row.object_name, 180) === entity.objectName)
      : rows;
    const usable = sameObject.length === 1 ? sameObject : rows.length === 1 ? rows : [];
    if (usable.length !== 1) {
      unresolved.push(entity.label);
      continue;
    }
    const shifts = Number(usable[0].shifts);
    if (!Number.isFinite(shifts) || shifts < 0 || shifts > 3) {
      unresolved.push(entity.label);
      continue;
    }
    prepared.push({ entity, shifts });
  }

  if (unresolved.length > 0) {
    return {
      error:
        `Не могу безопасно скопировать табель за ${sourceDate}: нет однозначной записи у ${unresolved.slice(0, 6).join(", ")}${unresolved.length > 6 ? "…" : ""}. Уточни значения вручную.`,
      status: 409,
    };
  }

  const actions = prepared.map(({ entity, shifts }) =>
    timesheetAction(entity, shifts, targetDate, sourceDate)
  );
  return {
    body: compoundBody({
      title: "Копирование табеля группы подготовлено",
      summary: `Скопировать значения ${sourceDate} → ${targetDate} для ${prepared.length} сотрудников.`,
      actions,
      labels: prepared.map(({ entity, shifts }) => `${entity.label}: ${shifts}`),
      date: targetDate,
    }),
    status: 200,
  };
}

export async function buildGroupReferencedFollowUp({
  client,
  companyId,
  role,
  assignedObject,
  prompt,
  date,
  conversationContext,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  prompt: string;
  date: string;
  conversationContext: GlobalVoiceConversationContext;
}): Promise<BuilderResult | null> {
  if (!conversationContext.topic || !groupReferenceIntent(prompt)) return null;

  const referenceSet = await loadReferenceSet({
    client,
    companyId,
    role,
    assignedObject,
    context: conversationContext,
  });
  if (referenceSet == null) return null;

  const selection = selectGroup(prompt, referenceSet.entities);
  if (!selection.entities) {
    return { error: selection.error ?? "Нужно уточнить группу из предыдущего результата", status: 409 };
  }
  const selected = selection.entities;
  const value = normalized(prompt);
  const copyPrevious = referenceSet.type === "employee" && sameAsYesterdayIntent(prompt);
  const effectiveDate = copyPrevious
    ? hasExplicitTargetDate(prompt)
      ? date
      : conversationContext.date || date
    : hasExplicitDate(prompt)
    ? date
    : conversationContext.date || date;

  if (referenceSet.type === "employee" && copyPrevious) {
    if (!managerRole(role) && role !== "foreman") {
      return { error: "Изменение табеля недоступно текущей роли", status: 403 };
    }
    const safe = role === "foreman"
      ? selected.filter((entity) => entity.objectName === assignedObject)
      : selected;
    if (safe.length !== selected.length) {
      return { error: "Прораб может менять табель только своего объекта", status: 403 };
    }
    return await copyPreviousAttendance({
      client,
      companyId,
      selected: safe,
      targetDate: effectiveDate,
      conversationDate: conversationContext.date,
    });
  }

  if (referenceSet.type === "employee") {
    if (!managerRole(role) && role !== "foreman") {
      return { error: "Изменение табеля недоступно текущей роли", status: 403 };
    }
    const shifts = shiftValue(prompt);
    const writeIntent = /(?:постав|простав|отмет|исправ|поправ|измени|сдел)/.test(value);
    if (!writeIntent || shifts == null) return null;
    const safe = role === "foreman"
      ? selected.filter((entity) => entity.objectName === assignedObject)
      : selected;
    if (safe.length !== selected.length) {
      return { error: "Прораб может менять табель только своего объекта", status: 403 };
    }
    const actions = safe.map((entity) => timesheetAction(entity, shifts, effectiveDate));
    return {
      body: compoundBody({
        title: "Групповой табель подготовлен",
        summary: `${safe.length} сотрудников → ${shifts} смены за ${effectiveDate}.`,
        actions,
        labels: safe.map((entity) => `${entity.label}: ${shifts}`),
        date: effectiveDate,
      }),
      status: 200,
    };
  }

  if (referenceSet.type === "candidate") {
    if (/(?:назнач|закреп|ответствен)/.test(value)) {
      return await buildCandidateBatch({
        client,
        companyId,
        role,
        date: effectiveDate,
        prompt,
        selected,
        stage: false,
      });
    }
    if (/(?:перевед|перекин|этап|стади)/.test(value)) {
      return await buildCandidateBatch({
        client,
        companyId,
        role,
        date: effectiveDate,
        prompt,
        selected,
        stage: true,
      });
    }
  }

  if (
    referenceSet.type === "procurement" &&
    /(?:перевед|провед|отмет|согласу|заказ|достав|отмен|закуп)/.test(value)
  ) {
    return await buildProcurementBatch({
      client,
      companyId,
      role,
      date: effectiveDate,
      prompt,
      selected,
    });
  }

  return null;
}
