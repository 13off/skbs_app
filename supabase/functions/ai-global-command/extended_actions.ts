import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.5";

import {
  clean,
  nameMatches,
  normalized,
  resultWithAction,
} from "./shared.ts";

type CandidateRow = {
  id: string;
  full_name: string;
};

type ResponsibleRow = {
  user_id: string;
  full_name: string;
  role: string;
};

type ObjectRow = {
  id: string;
  name: string;
};

function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

function hrRole(role: string) {
  return managerRole(role) || role === "hr";
}

function procurementRole(role: string) {
  return managerRole(role) || role === "procurement";
}

function legalRole(role: string) {
  return managerRole(role) || role === "lawyer";
}

function explicitDate(prompt: string): boolean {
  return /(?:сегодня|завтра|послезавтра|\b20\d{2}-\d{1,2}-\d{1,2}\b|\b\d{1,2}[./]\d{1,2})/i.test(
    prompt,
  );
}

function uniqueNameMatch<T>(
  prompt: string,
  rows: T[],
  nameOf: (row: T) => string,
): { row?: T; matches: T[] } {
  const matches = rows.filter((row) => nameMatches(prompt, nameOf(row)));
  return matches.length === 1 ? { row: matches[0], matches } : { matches };
}

export function candidateResponsibleIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:назнач|закреп|постав).*(?:ответствен).*(?:кандидат|соискател)|(?:кандидат|соискател).*(?:ответствен)/.test(
    value,
  );
}

export async function buildCandidateResponsible({
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
  if (!hrRole(role)) {
    return { error: "Назначение ответственного кандидату недоступно текущей роли", status: 403 };
  }

  const [{ data: candidateRows, error: candidateError }, responsibleResponse] =
    await Promise.all([
      client
        .from("recruitment_applications")
        .select("id, full_name")
        .eq("company_id", companyId)
        .is("archived_at", null)
        .order("updated_at", { ascending: false })
        .limit(500),
      client.rpc("get_recruitment_responsibles"),
    ]);
  if (candidateError) throw candidateError;
  if (responsibleResponse.error) throw responsibleResponse.error;

  const candidates = (candidateRows ?? []) as CandidateRow[];
  const responsibles = (responsibleResponse.data ?? []) as ResponsibleRow[];
  const candidateMatch = uniqueNameMatch(prompt, candidates, (item) => item.full_name);
  if (!candidateMatch.row) {
    if (candidateMatch.matches.length > 1) {
      return {
        error: `Нашёл несколько кандидатов: ${candidateMatch.matches
          .slice(0, 4)
          .map((item) => item.full_name)
          .join(", ")}. Уточни ФИО.`,
        status: 409,
      };
    }
    return { error: "Не нашёл кандидата по имени", status: 400 };
  }

  const responsibleMatch = uniqueNameMatch(
    prompt,
    responsibles,
    (item) => item.full_name,
  );
  if (!responsibleMatch.row) {
    if (responsibleMatch.matches.length > 1) {
      return {
        error: `Нашёл несколько ответственных: ${responsibleMatch.matches
          .slice(0, 4)
          .map((item) => item.full_name)
          .join(", ")}. Назови точнее.`,
        status: 409,
      };
    }
    return { error: "Не понял, кого назначить ответственным", status: 400 };
  }

  const candidate = candidateMatch.row;
  const responsible = responsibleMatch.row;
  return {
    body: resultWithAction({
      title: "Ответственный кандидата подготовлен",
      summary: `${candidate.full_name} → ${responsible.full_name}.`,
      highlights: [candidate.full_name, `Ответственный: ${responsible.full_name}`],
      warnings: ["Ответственный изменится только после подтверждения."],
      date,
      action: {
        id: crypto.randomUUID(),
        type: "assign_candidate_responsible",
        title: "Назначить ответственного кандидату",
        button_label: "Проверить назначение",
        confirmation_required: true,
        payload: {
          application_id: candidate.id,
          candidate_name: candidate.full_name,
          responsible_user_id: responsible.user_id,
          responsible_name: responsible.full_name,
          source_prompt: prompt,
        },
      },
    }),
    status: 200,
  };
}

export function createProcurementRequestIntent(prompt: string): boolean {
  const value = normalized(prompt);
  const create = /(?:созда|добав|оформ|заведи)/.test(value);
  const request = /(?:заявк)/.test(value);
  const procurement = /(?:снабжен|закуп|материал|арматур|бетон|опалуб|крепеж|инструмент)/.test(
    value,
  );
  return create && request && procurement;
}

function procurementUnit(raw: string): string {
  const value = normalized(raw);
  if (/^(?:кг|килограмм)/.test(value)) return "кг";
  if (/^(?:т|тон)/.test(value)) return "т";
  if (/^(?:м3|м³|куб)/.test(value)) return "м³";
  if (/^(?:м2|м²|квадрат)/.test(value)) return "м²";
  if (/^(?:м|метр)/.test(value)) return "м";
  if (/^(?:упак)/.test(value)) return "упак.";
  return "шт.";
}

function procurementItem(prompt: string) {
  const value = normalized(prompt);
  const match = value.match(
    /\b(\d+(?:[.,]\d+)?)\s*(шт\.?|штук\w*|кг|килограмм\w*|т|тонн\w*|м3|м³|куб\w*|м2|м²|квадрат\w*|м|метр\w*|упак\w*)\s+(.+?)(?=\s+(?:на\s+объект|для\s+объект|до\s+|к\s+|сегодня|завтра|послезавтра|сроч|приоритет)|$)/,
  );
  if (!match) return null;
  const quantity = Number(match[1].replace(",", "."));
  const name = clean(match[3], 160)
    .replace(/^(?:материал\w*\s+)?/, "")
    .trim();
  if (!Number.isFinite(quantity) || quantity <= 0 || !name) return null;
  return { quantity, unit: procurementUnit(match[2]), name };
}

async function resolveObject({
  client,
  companyId,
  requestedObject,
  prompt,
}: {
  client: SupabaseClient;
  companyId: string;
  requestedObject: string;
  prompt: string;
}) {
  const { data, error } = await client
    .from("objects")
    .select("id, name")
    .eq("company_id", companyId)
    .eq("is_active", true)
    .order("name")
    .limit(300);
  if (error) throw error;
  const objects = (data ?? []) as ObjectRow[];
  if (objects.length === 0) return { error: "В компании нет активных объектов", status: 400 };

  const requested = normalized(requestedObject);
  if (requested) {
    const exact = objects.filter((item) => normalized(item.name) === requested);
    if (exact.length === 1) return { row: exact[0] };
  }

  const matches = objects.filter((item) => nameMatches(prompt, item.name));
  if (matches.length === 1) return { row: matches[0] };
  if (matches.length > 1) {
    return {
      error: `Нашёл несколько объектов: ${matches.slice(0, 4).map((item) => item.name).join(", ")}. Уточни объект.`,
      status: 409,
    };
  }
  if (objects.length === 1) return { row: objects[0] };
  return { error: "Для заявки назови объект", status: 400 };
}

function procurementPriority(prompt: string): string {
  const value = normalized(prompt);
  if (/(?:сроч|аварийн|критич)/.test(value)) return "urgent";
  if (/(?:высок\w*\s+приоритет)/.test(value)) return "high";
  if (/(?:низк\w*\s+приоритет)/.test(value)) return "low";
  return "normal";
}

export async function buildCreateProcurementRequest({
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
  if (!procurementRole(role)) {
    return { error: "Создание заявок снабжения недоступно текущей роли", status: 403 };
  }
  const item = procurementItem(prompt);
  if (!item) {
    return {
      error: "Для новой заявки скажи количество, единицу и материал. Например: 200 кг арматуры.",
      status: 400,
    };
  }

  const objectResult = await resolveObject({
    client,
    companyId,
    requestedObject: requestedObject || assignedObject,
    prompt,
  });
  if (!("row" in objectResult)) return objectResult;
  const object = objectResult.row!;
  const neededBy = explicitDate(prompt) ? date : "";
  const priority = procurementPriority(prompt);
  const title = `${item.name} — ${item.quantity} ${item.unit}`;

  return {
    body: resultWithAction({
      title: "Заявка снабжения подготовлена",
      summary: `${object.name}: ${title}.`,
      highlights: [
        `Объект: ${object.name}`,
        `Материал: ${item.name}`,
        `Количество: ${item.quantity} ${item.unit}`,
        priority === "urgent" ? "Приоритет: срочно" : "Приоритет: обычный",
        ifDate(neededBy, `Нужно к: ${neededBy}`),
      ].filter(Boolean) as string[],
      warnings: ["Заявка создастся только после подтверждения."],
      objectName: object.name,
      date,
      action: {
        id: crypto.randomUUID(),
        type: "create_procurement_request",
        title: "Создать заявку снабжения",
        button_label: "Проверить заявку",
        confirmation_required: true,
        payload: {
          object_id: object.id,
          object_name: object.name,
          title,
          item_name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          priority,
          needed_by: neededBy,
          source_prompt: prompt,
        },
      },
    }),
    status: 200,
  };
}

function ifDate(value: string, label: string): string {
  return value ? label : "";
}

export function createLegalMatterIntent(prompt: string): boolean {
  const value = normalized(prompt);
  const create = /(?:созда|добав|заведи|оформ)/.test(value);
  const legal = /(?:юрид)/.test(value);
  const matter = /(?:вопрос|задач|дело|риск)/.test(value);
  return create && legal && matter;
}

function legalMatterTitle(prompt: string): string {
  const raw = prompt.match(
    /(?:созда\w*|добав\w*|завед\w*|оформ\w*)\s+(?:нов\w*\s+)?юридическ\w*\s+(?:вопрос|задач\w*|дело|риск)\s*[:\-]?\s*(.+)$/i,
  )?.[1];
  let title = clean(raw, 220);
  title = title
    .replace(/\s+(?:до|к)\s+(?:сегодня|завтра|послезавтра|\d{1,2}[./]\d{1,2}(?:[./]20\d{2})?).*$/i, "")
    .trim();
  return title;
}

function legalRisk(prompt: string): string {
  const value = normalized(prompt);
  if (/(?:критич|максимальн\w*\s+риск)/.test(value)) return "critical";
  if (/(?:высок\w*\s+риск|серьезн\w*\s+риск)/.test(value)) return "high";
  if (/(?:низк\w*\s+риск)/.test(value)) return "low";
  return "medium";
}

export async function buildCreateLegalMatter({
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
  if (!legalRole(role)) {
    return { error: "Создание юридических вопросов недоступно текущей роли", status: 403 };
  }
  const title = legalMatterTitle(prompt);
  if (title.length < 4) {
    return { error: "После слов «создай юридическую задачу» назови сам вопрос", status: 400 };
  }

  let object: ObjectRow | null = null;
  if (requestedObject || /(?:объект)/i.test(prompt)) {
    const objectResult = await resolveObject({
      client,
      companyId,
      requestedObject,
      prompt,
    });
    if (!("row" in objectResult)) return objectResult;
    object = objectResult.row!;
  }
  const dueAt = explicitDate(prompt) ? date : "";
  const riskLevel = legalRisk(prompt);
  const requiresManagerDecision = /(?:решен\w*\s+руковод|согласован\w*\s+руковод)/.test(
    normalized(prompt),
  );

  return {
    body: resultWithAction({
      title: "Юридический вопрос подготовлен",
      summary: title,
      highlights: [
        `Риск: ${riskLevel}`,
        object ? `Объект: ${object.name}` : "",
        dueAt ? `Срок: ${dueAt}` : "",
        requiresManagerDecision ? "Потребуется решение руководителя" : "",
      ].filter(Boolean),
      warnings: ["Юридический вопрос создастся только после подтверждения."],
      objectName: object?.name ?? "",
      date,
      action: {
        id: crypto.randomUUID(),
        type: "create_legal_matter",
        title: "Создать юридический вопрос",
        button_label: "Проверить вопрос",
        confirmation_required: true,
        payload: {
          title,
          description: title,
          matter_type: "task",
          risk_level: riskLevel,
          due_at: dueAt,
          object_id: object?.id ?? "",
          object_name: object?.name ?? "",
          required_actions: title,
          requires_manager_decision: requiresManagerDecision,
          manager_question: requiresManagerDecision ? title : "",
          source_prompt: prompt,
        },
      },
    }),
    status: 200,
  };
}
