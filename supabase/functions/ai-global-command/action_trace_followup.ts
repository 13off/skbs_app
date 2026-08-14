import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.5";

import type { GlobalVoiceConversationContext } from "./conversation_context.ts";
import { buildCandidateResponsible } from "./extended_actions.ts";
import {
  buildHrStageMove,
  buildProcurementStatus,
} from "./professional_actions.ts";
import { referenceWords, shiftValue } from "./reference_followup.ts";
import { clean, normalized, resultWithAction } from "./shared.ts";

type BuilderResult =
  | { body: Record<string, unknown>; status: number }
  | { error: string; status: number };

type TraceEntityType = "employee" | "candidate" | "procurement";

type TraceStep = {
  kind: string;
  entityType: TraceEntityType;
  id: string;
  label: string;
  objectName: string;
  date: string;
  shifts: number | null;
};

type ActionTrace = {
  issuedAt: number;
  steps: TraceStep[];
};

type CandidateRow = {
  id: string;
  full_name: string;
  source: string;
  external_user_id: string | null;
  external_chat_id: string | null;
};

type EmployeeRow = {
  id: string;
  fio: string;
  object_name: string;
};

type ProcurementRow = {
  id: string;
  title: string;
  object_name: string | null;
  status: string;
};

type ResolvedTarget = {
  id: string;
  label: string;
  objectName: string;
  source?: string;
  externalUserId?: string;
  externalChatId?: string;
  status?: string;
};

const traceTtlMs = 15 * 60 * 1000;
const futureSkewMs = 2 * 60 * 1000;
const pluralPronouns = new Set([
  "им",
  "их",
  "ими",
  "этим",
  "этих",
  "эти",
  "этими",
  "всем",
  "всех",
]);
const singularPronouns = new Set([
  "ему",
  "ей",
  "его",
  "ее",
  "этому",
  "этой",
  "этого",
  "эту",
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

function hrRole(role: string) {
  return managerRole(role) || role === "hr";
}

function procurementRole(role: string) {
  return managerRole(role) || role === "procurement";
}

function map(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function parseTrace(context: GlobalVoiceConversationContext): ActionTrace | null {
  if (context.topic !== "action_trace" || context.queryMode !== "action") {
    return null;
  }
  let raw: Record<string, unknown>;
  try {
    const decoded = JSON.parse(context.prompt);
    raw = map(decoded);
  } catch (_) {
    return null;
  }
  if (Number(raw.v) !== 1) return null;
  const issuedAt = Number(raw.iat);
  const now = Date.now();
  if (!Number.isFinite(issuedAt)) return null;
  if (issuedAt > now + futureSkewMs || now - issuedAt > traceTtlMs) return null;

  const rawSteps = Array.isArray(raw.steps) ? raw.steps.slice(0, 30) : [];
  const steps: TraceStep[] = [];
  for (const value of rawSteps) {
    const item = map(value);
    const entityType = clean(item.et, 30) as TraceEntityType;
    if (!new Set(["employee", "candidate", "procurement"]).has(entityType)) {
      continue;
    }
    const id = clean(item.id, 80);
    const label = clean(item.label, 220);
    if (!id || !label) continue;
    const shiftsRaw = Number(item.shifts);
    steps.push({
      kind: clean(item.k, 80),
      entityType,
      id,
      label,
      objectName: clean(item.object, 180),
      date: clean(item.date, 10),
      shifts: Number.isFinite(shiftsRaw) ? shiftsRaw : null,
    });
  }
  if (steps.length === 0) return null;
  return { issuedAt, steps };
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

function hasReferenceMarker(prompt: string): boolean {
  const value = normalized(prompt);
  if (/\bобъект/.test(value) &&
      !/(?:кандидат|сотрудник|заявк|назначенн|выбранн|из\s+них)/.test(value)) {
    return false;
  }
  const words = referenceWords(prompt);
  if (words.some((word) => pluralPronouns.has(word) || singularPronouns.has(word))) {
    return true;
  }
  if (words.some((word) => ordinalForWord(word) != null)) return true;
  if (/(?:из\s+назначенн|из\s+выбранн|из\s+них|назначенн(?:ым|ых|ого|ому)?|выбранн(?:ым|ых|ого|ому)?)/.test(value)) {
    return true;
  }
  if (/(?:сделай|повтори).*(?:так\s+же|то\s+же)/.test(value)) return true;
  return false;
}

function selectSteps(
  prompt: string,
  steps: TraceStep[],
): { steps?: TraceStep[]; error?: string } {
  if (steps.length === 0) {
    return { error: "Предыдущее действие уже не содержит доступных объектов." };
  }
  const words = referenceWords(prompt);
  const ordinals = ordinalIndexes(prompt);

  if (words.includes("по") && ordinals.length >= 2) {
    const start = ordinals[0] < 0 ? steps.length - 1 : ordinals[0];
    const end = ordinals[1] < 0 ? steps.length - 1 : ordinals[1];
    if (start < 0 || end < 0 || start >= steps.length || end >= steps.length) {
      return { error: `В предыдущем действии только ${steps.length} позиций.` };
    }
    if (start > end) return { error: "Диапазон нужно назвать от первой позиции к последней." };
    return { steps: steps.slice(start, end + 1) };
  }

  const excluded = ordinalAfter(words, "кроме");
  if (excluded != null) {
    const index = excluded < 0 ? steps.length - 1 : excluded;
    if (index < 0 || index >= steps.length) {
      return { error: `В предыдущем действии только ${steps.length} позиций.` };
    }
    const remaining = steps.filter((_, itemIndex) => itemIndex !== index);
    return remaining.length === 0
      ? { error: "После исключения никого не осталось." }
      : { steps: remaining };
  }

  const count = groupCount(prompt);
  if (count != null) {
    if (count > steps.length) {
      return { error: `В предыдущем действии только ${steps.length}, а запрошено ${count}.` };
    }
    if (words.some((word) => word.startsWith("перв"))) {
      return { steps: steps.slice(0, count) };
    }
    if (words.some((word) => word.startsWith("последн"))) {
      return { steps: steps.slice(steps.length - count) };
    }
    if (steps.length === count) return { steps };
    return {
      error: `Не понял, какие именно ${count} из ${steps.length} выбрать. Скажи «первых ${count}» или «последних ${count}».`,
    };
  }

  const ordinal = ordinals[0];
  if (ordinal != null) {
    const index = ordinal < 0 ? steps.length - 1 : ordinal;
    if (index < 0 || index >= steps.length) {
      return { error: `В предыдущем действии только ${steps.length} позиций.` };
    }
    return { steps: [steps[index]] };
  }

  if (words.some((word) => pluralPronouns.has(word)) ||
      /(?:назначенн|выбранн|из\s+них)/.test(normalized(prompt))) {
    if (steps.length > 30) return { error: "Предыдущая группа слишком большая." };
    return { steps };
  }

  if (words.some((word) => singularPronouns.has(word))) {
    if (steps.length === 1) return { steps: [steps[0]] };
    return {
      error: `В предыдущем действии ${steps.length} позиций. Скажи «первому», «второму» или назови человека.`,
    };
  }

  if (/(?:сделай|повтори).*(?:так\s+же|то\s+же)/.test(normalized(prompt))) {
    return { steps };
  }
  return { error: "Не понял, на какую часть предыдущего действия ты ссылаешься." };
}

function explicitEntityType(prompt: string): TraceEntityType | null {
  const value = normalized(prompt);
  if (/(?:кандидат|соискател|назначенн)/.test(value)) return "candidate";
  if (/(?:сотрудник|работник|табел|смен)/.test(value)) return "employee";
  if (/(?:заявк|снабжен|закуп|поставк)/.test(value)) return "procurement";
  return null;
}

function chooseEntityType(
  prompt: string,
  steps: TraceStep[],
): { type?: TraceEntityType; steps?: TraceStep[]; error?: string } {
  const explicit = explicitEntityType(prompt);
  const types = [...new Set(steps.map((step) => step.entityType))];
  if (explicit != null) {
    const filtered = steps.filter((step) => step.entityType === explicit);
    if (filtered.length === 0) {
      return { error: "В предыдущем действии нет объектов этого типа." };
    }
    return { type: explicit, steps: filtered };
  }
  if (types.length !== 1) {
    return {
      error: "Предыдущее действие было смешанным. Уточни: кандидаты, сотрудники или заявки снабжения.",
    };
  }
  return { type: types[0], steps };
}

function sameIdsInOrder<T extends { id: string }>(
  steps: TraceStep[],
  rows: T[],
): T[] | null {
  const byId = new Map(rows.map((row) => [row.id, row]));
  const ordered: T[] = [];
  for (const step of steps) {
    const row = byId.get(step.id);
    if (row == null) return null;
    ordered.push(row);
  }
  return ordered;
}

async function resolveTargets({
  client,
  companyId,
  role,
  assignedObject,
  entityType,
  steps,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  entityType: TraceEntityType;
  steps: TraceStep[];
}): Promise<{ targets?: ResolvedTarget[]; error?: string; status?: number }> {
  const ids = [...new Set(steps.map((step) => step.id))];
  if (ids.length === 0) return { error: "Предыдущая ссылка пуста", status: 409 };

  if (entityType === "candidate") {
    if (!hrRole(role)) return { error: "Кандидаты недоступны текущей роли", status: 403 };
    const { data, error } = await client
      .from("recruitment_applications")
      .select("id, full_name, source, external_user_id, external_chat_id")
      .eq("company_id", companyId)
      .in("id", ids)
      .is("archived_at", null);
    if (error) throw error;
    const rows = sameIdsInOrder(steps, (data ?? []) as CandidateRow[]);
    if (rows == null) {
      return { error: "Часть кандидатов из предыдущего действия уже изменилась или недоступна. Повтори исходный запрос.", status: 409 };
    }
    return {
      targets: rows.map((row) => ({
        id: row.id,
        label: clean(row.full_name, 180),
        objectName: "",
        source: clean(row.source, 30),
        externalUserId: clean(row.external_user_id, 120),
        externalChatId: clean(row.external_chat_id, 120),
      })),
    };
  }

  if (entityType === "employee") {
    if (!managerRole(role) && role !== "foreman") {
      return { error: "Табель сотрудников недоступен текущей роли", status: 403 };
    }
    let query = client
      .from("employees")
      .select("id, fio, object_name")
      .eq("company_id", companyId)
      .in("id", ids)
      .eq("is_active", true)
      .is("archived_at", null);
    if (role === "foreman") query = query.eq("object_name", assignedObject);
    const { data, error } = await query;
    if (error) throw error;
    const rows = sameIdsInOrder(steps, (data ?? []) as EmployeeRow[]);
    if (rows == null) {
      return { error: "Часть сотрудников из предыдущего действия уже недоступна или находится вне твоего объекта.", status: 409 };
    }
    return {
      targets: rows.map((row) => ({
        id: row.id,
        label: clean(row.fio, 180),
        objectName: clean(row.object_name, 180),
      })),
    };
  }

  if (!procurementRole(role)) {
    return { error: "Снабжение недоступно текущей роли", status: 403 };
  }
  const { data, error } = await client
    .from("procurement_requests")
    .select("id, title, object_name, status")
    .eq("company_id", companyId)
    .in("id", ids);
  if (error) throw error;
  const rows = sameIdsInOrder(steps, (data ?? []) as ProcurementRow[]);
  if (rows == null) {
    return { error: "Часть заявок из предыдущего действия уже недоступна.", status: 409 };
  }
  return {
    targets: rows.map((row) => ({
      id: row.id,
      label: clean(row.title, 220),
      objectName: clean(row.object_name, 180),
      status: clean(row.status, 60),
    })),
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
    warnings: ["Это цепочка действий. Каждый шаг проходит штатное подтверждение и аудит."],
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

function hasExplicitDate(prompt: string): boolean {
  return /(?:сегодня|завтра|послезавтра|вчера|(?:^|\s)20\d{2}-\d{1,2}-\d{1,2}(?=\s|$)|(?:^|\s)\d{1,2}[./]\d{1,2}(?:[./]20\d{2})?(?=\s|$))/i.test(prompt);
}

function timesheetAction(target: ResolvedTarget, shifts: number, date: string) {
  return {
    id: crypto.randomUUID(),
    type: "prepare_timesheet_correction",
    title: "Корректировка табеля",
    button_label: "Проверить и применить",
    confirmation_required: true,
    payload: {
      employee_id: target.id,
      employee_name: target.label,
      object_name: target.objectName,
      date,
      shifts,
      source_prompt: "voice_action_trace_followup",
    },
  };
}

async function buildCandidateBatch({
  client,
  companyId,
  role,
  date,
  prompt,
  targets,
  stage,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  date: string;
  prompt: string;
  targets: ResolvedTarget[];
  stage: boolean;
}): Promise<BuilderResult> {
  const actions: Record<string, unknown>[] = [];
  const labels: string[] = [];
  for (const target of targets) {
    const explicit = stage
      ? `${target.label}. ${prompt}. переведи кандидата на этап`
      : `${target.label}. ${prompt}. назначь ответственного кандидату`;
    const result = stage
      ? await buildHrStageMove({ client, companyId, role, prompt: explicit, date })
      : await buildCandidateResponsible({ client, companyId, role, prompt: explicit, date });
    if ("error" in result) return result;
    const action = (result.body as any).action;
    if (action && typeof action === "object") actions.push(action);
    labels.push((result.body as any).summary ?? target.label);
  }
  return {
    body: compoundBody({
      title: stage ? "Переход выбранных кандидатов подготовлен" : "Ответственные выбранным кандидатам подготовлены",
      summary: `Продолжил предыдущее действие для ${actions.length} кандидатов.`,
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
  targets,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  date: string;
  prompt: string;
  targets: ResolvedTarget[];
}): Promise<BuilderResult> {
  const actions: Record<string, unknown>[] = [];
  const labels: string[] = [];
  for (const target of targets) {
    const result = await buildProcurementStatus({
      client,
      companyId,
      role,
      prompt: `${target.label}. ${prompt}. заявка снабжения`,
      date,
      requestedObject: target.objectName,
    });
    if ("error" in result) return result;
    const action = (result.body as any).action;
    if (action && typeof action === "object") actions.push(action);
    labels.push((result.body as any).summary ?? target.label);
  }
  return {
    body: compoundBody({
      title: "Продолжение снабжения подготовлено",
      summary: `Продолжил предыдущее действие для ${actions.length} заявок.`,
      actions,
      labels,
      date,
    }),
    status: 200,
  };
}

function candidateMessageBody(prompt: string): string {
  const colon = prompt.match(/[:\-]\s*(.+)$/s)?.[1];
  if (colon?.trim()) return clean(colon, 4000);
  const what = prompt.match(/\bчто\s+(.+)$/is)?.[1];
  if (what?.trim()) return clean(what, 4000);
  const message = prompt.match(/\bсообщени\w*\s+(.+)$/is)?.[1];
  return clean(message, 4000);
}

function candidateMessageIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:напиши|отправь|сообщи|черкни)/.test(value) &&
    /(?:им|их|ему|ей|кандидат|назначенн|выбранн|перв|втор|трет|последн)/.test(value);
}

function canMessageCandidate(target: ResolvedTarget): boolean {
  if (target.source === "telegram") return (target.externalChatId ?? "").length > 0;
  if (target.source === "max") return (target.externalUserId ?? "").length > 0;
  return false;
}

function candidateMessageAction(target: ResolvedTarget, body: string) {
  return {
    id: crypto.randomUUID(),
    type: "send_candidate_message",
    title: `Отправить сообщение: ${target.label}`,
    button_label: "Проверить сообщение",
    confirmation_required: true,
    payload: {
      application_id: target.id,
      candidate_name: target.label,
      source: target.source ?? "",
      body,
      source_prompt: "voice_action_trace_followup",
    },
  };
}

function openCandidateIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /^(?:открой|перейди|зайди)\b/.test(value) &&
    /(?:кандидат|назначенн|выбранн|из\s+них|его|ее|втор|перв|трет|последн)/.test(value);
}

export async function buildActionTraceFollowUp({
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
  const trace = parseTrace(conversationContext);
  if (trace == null || !hasReferenceMarker(prompt)) return null;

  const typed = chooseEntityType(prompt, trace.steps);
  if (!typed.steps || !typed.type) {
    return { error: typed.error ?? "Не понял тип ссылки на предыдущее действие", status: 409 };
  }
  const selection = selectSteps(prompt, typed.steps);
  if (!selection.steps) {
    return { error: selection.error ?? "Не понял ссылку на предыдущее действие", status: 409 };
  }

  const resolved = await resolveTargets({
    client,
    companyId,
    role,
    assignedObject,
    entityType: typed.type,
    steps: selection.steps,
  });
  if (!resolved.targets) {
    return { error: resolved.error ?? "Не удалось восстановить предыдущее действие", status: resolved.status ?? 409 };
  }
  const targets = resolved.targets;
  const value = normalized(prompt);
  const effectiveDate = hasExplicitDate(prompt)
    ? date
    : conversationContext.date || date;

  if (typed.type === "candidate") {
    if (openCandidateIntent(prompt)) {
      if (targets.length !== 1) {
        return { error: `Для открытия карточки выбери одного кандидата, сейчас выбрано ${targets.length}.`, status: 409 };
      }
      const target = targets[0];
      return {
        body: resultWithAction({
          title: target.label,
          summary: `Открыть карточку кандидата ${target.label}.`,
          highlights: [target.label],
          date: effectiveDate,
          action: {
            id: crypto.randomUUID(),
            type: "open_candidate_detail",
            title: `Открыть ${target.label}`,
            button_label: "Открыть карточку",
            confirmation_required: false,
            payload: {
              application_id: target.id,
              candidate_name: target.label,
              source_prompt: prompt,
            },
          },
        }),
        status: 200,
      };
    }

    if (candidateMessageIntent(prompt)) {
      const body = candidateMessageBody(prompt);
      if (!body) {
        return { error: "Скажи текст сообщения после двоеточия или после слова «что».", status: 400 };
      }
      const unavailable = targets.filter((target) => !canMessageCandidate(target));
      if (unavailable.length > 0) {
        return {
          error: `Нельзя безопасно отправить сообщение через бот: ${unavailable.map((item) => item.label).join(", ")}. У них нет активного Telegram/MAX-канала.`,
          status: 409,
        };
      }
      const actions = targets.map((target) => candidateMessageAction(target, body));
      return {
        body: compoundBody({
          title: "Сообщения кандидатам подготовлены",
          summary: `Получателей: ${targets.length}. Текст: ${body}`,
          actions,
          labels: targets.map((target) => `${target.label} • ${target.source}`),
          date: effectiveDate,
        }),
        status: 200,
      };
    }

    if (/(?:назнач|закреп|ответствен)/.test(value)) {
      return await buildCandidateBatch({
        client,
        companyId,
        role,
        date: effectiveDate,
        prompt,
        targets,
        stage: false,
      });
    }
    if (/(?:перевед|перемест|перекин|этап|стади|билет)/.test(value)) {
      return await buildCandidateBatch({
        client,
        companyId,
        role,
        date: effectiveDate,
        prompt,
        targets,
        stage: true,
      });
    }
  }

  if (typed.type === "employee") {
    const explicitShifts = shiftValue(prompt);
    const replay = /(?:сделай|повтори).*(?:так\s+же|то\s+же)/.test(value);
    if (explicitShifts != null) {
      const actions = targets.map((target) => timesheetAction(target, explicitShifts, effectiveDate));
      return {
        body: compoundBody({
          title: "Продолжение табеля подготовлено",
          summary: `${targets.length} сотрудников → ${explicitShifts} смены за ${effectiveDate}.`,
          actions,
          labels: targets.map((target) => `${target.label}: ${explicitShifts}`),
          date: effectiveDate,
        }),
        status: 200,
      };
    }
    if (replay) {
      if (!hasExplicitDate(prompt) && effectiveDate === conversationContext.date) {
        return { error: "Чтобы не продублировать тот же табель, назови новую дату: например «так же завтра».", status: 409 };
      }
      const shiftById = new Map(
        selection.steps
          .filter((step) => step.shifts != null)
          .map((step) => [step.id, step.shifts as number]),
      );
      if (targets.some((target) => !shiftById.has(target.id))) {
        return { error: "В предыдущем действии нет точного значения смен для каждого выбранного сотрудника.", status: 409 };
      }
      const actions = targets.map((target) =>
        timesheetAction(target, shiftById.get(target.id)!, effectiveDate)
      );
      return {
        body: compoundBody({
          title: "Табель повторён по безопасному шаблону",
          summary: `Перенёс точные значения предыдущего действия на ${effectiveDate}; данные ещё не изменены.`,
          actions,
          labels: targets.map((target) => `${target.label}: ${shiftById.get(target.id)}`),
          date: effectiveDate,
        }),
        status: 200,
      };
    }
  }

  if (
    typed.type === "procurement" &&
    /(?:перевед|провед|отмет|согласу|заказ|достав|отмен|закуп|следующ|дальше)/.test(value)
  ) {
    return await buildProcurementBatch({
      client,
      companyId,
      role,
      date: effectiveDate,
      prompt,
      targets,
    });
  }

  return null;
}
