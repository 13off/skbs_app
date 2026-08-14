import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.5";

import type { GlobalVoiceConversationContext } from "./conversation_context.ts";
import { buildCandidateResponsible } from "./extended_actions.ts";
import {
  buildHrStageMove,
  buildProcurementStatus,
} from "./professional_actions.ts";
import { clean, normalized, resultWithAction } from "./shared.ts";

type ReferenceEntity = {
  id: string;
  label: string;
  objectName: string;
  status?: string;
};

type ReferenceSet = {
  type: "employee" | "candidate" | "procurement" | "task";
  entities: ReferenceEntity[];
};

type BuilderResult =
  | { body: Record<string, unknown>; status: number }
  | { error: string; status: number };

const pluralPronouns = new Set(["им", "их", "ими", "этим", "этих"]);
const singularPronouns = new Set([
  "этому",
  "этой",
  "этого",
  "эту",
  "ему",
  "ей",
  "его",
  "ее",
]);
const ordinalRoots: Array<[string, number]> = [
  ["перв", 0],
  ["втор", 1],
  ["трет", 2],
  ["четверт", 3],
  ["пят", 4],
  ["последн", -1],
];

function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

// JavaScript \b/\w are ASCII-oriented and are unsafe as Russian word
// boundaries. All reference parsing is therefore lexeme-based. Leading and
// trailing punctuation is stripped while decimal punctuation inside 0,5 stays.
export function referenceWords(prompt: string): string[] {
  return normalized(prompt)
    .replace(/[^а-яa-z0-9.,]+/g, " ")
    .split(/\s+/)
    .map((word) => word.replace(/^[.,]+|[.,]+$/g, ""))
    .filter(Boolean);
}

function hasReferencePhrase(prompt: string): boolean {
  const words = referenceWords(prompt);
  return words.some((word) =>
    pluralPronouns.has(word) ||
    singularPronouns.has(word) ||
    ordinalRoots.some(([root]) => word.startsWith(root))
  );
}

function hasExplicitDate(prompt: string): boolean {
  return /(?:сегодня|завтра|послезавтра|вчера|(?:^|\s)20\d{2}-\d{1,2}-\d{1,2}(?=\s|$)|(?:^|\s)\d{1,2}[./]\d{1,2}(?:[./]20\d{2})?(?=\s|$))/i.test(
    prompt,
  );
}

function ordinalIndex(prompt: string): number | null {
  const words = referenceWords(prompt);
  for (const [root, index] of ordinalRoots) {
    if (words.some((word) => word.startsWith(root))) return index;
  }
  return null;
}

function pluralReference(prompt: string): boolean {
  return referenceWords(prompt).some((word) => pluralPronouns.has(word));
}

function singularReference(prompt: string): boolean {
  return referenceWords(prompt).some((word) => singularPronouns.has(word));
}

function selectEntities(
  prompt: string,
  entities: ReferenceEntity[],
): { entities?: ReferenceEntity[]; error?: string } {
  if (entities.length === 0) {
    return { error: "Предыдущий список уже пуст или изменился. Повтори исходный запрос." };
  }

  const index = ordinalIndex(prompt);
  if (index != null) {
    const resolvedIndex = index < 0 ? entities.length - 1 : index;
    if (resolvedIndex < 0 || resolvedIndex >= entities.length) {
      return {
        error: `В предыдущем списке только ${entities.length}. Уточни, кого именно выбрать.`,
      };
    }
    return { entities: [entities[resolvedIndex]] };
  }

  if (pluralReference(prompt)) {
    if (entities.length > 30) {
      return {
        error: `В предыдущем результате ${entities.length} записей. Для массового изменения назови более узкую группу или конкретных людей.`,
      };
    }
    return { entities };
  }

  if (singularReference(prompt)) {
    if (entities.length === 1) return { entities: [entities[0]] };
    return {
      error: `В предыдущем результате ${entities.length} записей. Скажи «первому», «второму» или назови человека.`,
    };
  }

  return { error: "Не понял, на кого из предыдущего результата ты ссылаешься." };
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

  const attendance = new Map<string, number>();
  for (const row of attendanceResult.data ?? []) {
    const id = clean((row as any).employee_id, 80);
    attendance.set(id, Number((row as any).shifts ?? 0));
  }
  const entities: ReferenceEntity[] = [];
  for (const row of employeesResult.data ?? []) {
    const id = clean((row as any).id, 80);
    const shifts = attendance.get(id);
    if (shifts != null && Number.isFinite(shifts) && shifts > 0) continue;
    entities.push({
      id,
      label: clean((row as any).fio, 180),
      objectName: clean((row as any).object_name, 180),
    });
  }
  return { type: "employee", entities: entities.slice(0, 30) };
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
    .select("id, title, status, object_name")
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
      status: clean(row.status, 40),
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

export function shiftValue(prompt: string): number | null {
  const value = normalized(prompt);
  const words = referenceWords(prompt);
  const exact = (candidates: string[]) => candidates.some((item) => words.includes(item));
  const prefix = (roots: string[]) => roots.some((root) =>
    words.some((word) => word.startsWith(root))
  );

  if (exact(["0", "ноль", "нули", "нолик"]) || prefix(["нулев"])) return 0;
  if (exact(["0.5", "0,5", "полсмены"]) || /пол\s+смен/.test(value)) return 0.5;
  if (exact(["1", "один", "одну"]) || prefix(["единиц", "единичк"])) return 1;
  if (exact(["1.5", "1,5"]) || prefix(["полтор"])) return 1.5;
  if (exact(["2", "два", "две"]) || prefix(["двойк"])) return 2;
  if (exact(["2.5", "2,5"]) || /два\s+с\s+половин/.test(value)) return 2.5;
  if (exact(["3", "три"]) || prefix(["тройк"])) return 3;
  if (/(?:не\s+выш|не\s+явил|отсутств|прогул)/.test(value)) return 0;
  return null;
}

function referencedTimesheetIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:постав|простав|отмет|исправ|поправ|измени|сдел)/.test(value) &&
    shiftValue(prompt) != null;
}

function timesheetAction(entity: ReferenceEntity, shifts: number, date: string) {
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
      source_prompt: "voice_reference_followup",
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
    warnings: [
      "Это пакет действий. Каждый шаг проходит обычную проверку, роли и подтверждение.",
    ],
    date,
    action: {
      id: crypto.randomUUID(),
      type: "voice_compound_batch",
      title: `Выполнить ${actions.length} действий по очереди`,
      button_label: `Проверить ${actions.length} действий`,
      confirmation_required: true,
      payload: {
        actions,
        source_prompts: labels,
      },
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
  return {
    body: compoundBody({
      title: stage ? "Переход кандидатов подготовлен" : "Ответственные подготовлены",
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
  return {
    body: compoundBody({
      title: "Статусы снабжения подготовлены",
      summary: `Подготовлено действий: ${actions.length}.`,
      actions,
      labels,
      date,
    }),
    status: 200,
  };
}

export async function buildReferencedFollowUp({
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
  if (!conversationContext.topic || !hasReferencePhrase(prompt)) return null;

  const referenceSet = await loadReferenceSet({
    client,
    companyId,
    role,
    assignedObject,
    context: conversationContext,
  });
  if (referenceSet == null) return null;

  const selection = selectEntities(prompt, referenceSet.entities);
  if (!selection.entities) {
    return { error: selection.error ?? "Нужно уточнить ссылку на предыдущий результат", status: 409 };
  }
  const selected = selection.entities;
  const value = normalized(prompt);
  const effectiveDate = hasExplicitDate(prompt)
    ? date
    : conversationContext.date || date;

  if (referenceSet.type === "employee" && referencedTimesheetIntent(prompt)) {
    if (!managerRole(role) && role !== "foreman") {
      return { error: "Изменение табеля недоступно текущей роли", status: 403 };
    }
    const shifts = shiftValue(prompt);
    if (shifts == null) return { error: "Укажи количество смен от 0 до 3", status: 400 };
    const safe = role === "foreman"
      ? selected.filter((entity) => entity.objectName === assignedObject)
      : selected;
    if (safe.length !== selected.length) {
      return { error: "Прораб может менять табель только своего объекта", status: 403 };
    }
    const actions = safe.map((entity) => timesheetAction(entity, shifts, effectiveDate));
    return {
      body: compoundBody({
        title: "Табель по предыдущему результату подготовлен",
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
