import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import {
  clean,
  nameMatches,
  normalized,
  resultWithAction,
  tokens,
} from "./shared.ts";

type CandidateRow = {
  id: string;
  full_name: string;
  stage_id: string | null;
  object_id: string | null;
};

type StageRow = {
  id: string;
  system_key: string | null;
  title: string;
};

type MatterRow = {
  id: string;
  title: string;
  manager_question: string | null;
  decision_status: string | null;
  requires_manager_decision: boolean;
};

type ProcurementRow = {
  id: string;
  title: string;
  object_name: string | null;
  status: string;
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

function significantTokens(value: string): string[] {
  const ignored = new Set([
    "переведи", "перевести", "поставь", "поставить", "назначь", "назначить",
    "кандидата", "кандидат", "этап", "статус", "заявку", "заявка", "заявки",
    "согласуй", "согласовать", "одобри", "одобрить", "отклони", "отклонить",
    "решение", "вопрос", "юридический", "юридическое", "закупку", "закупка",
    "доставку", "доставка", "отметь", "отметить", "как", "на", "в", "по",
    "до", "для", "и", "а", "с", "со", "этот", "эту", "это", "следующий",
  ]);
  return tokens(value).filter((token) => token.length >= 3 && !ignored.has(token));
}

function overlapScore(prompt: string, title: string): number {
  const titleTokens = significantTokens(title);
  if (titleTokens.length === 0) return 0;
  const promptTokens = significantTokens(prompt);
  let matches = 0;
  for (const titleToken of titleTokens) {
    if (promptTokens.some((promptToken) => {
      if (promptToken === titleToken) return true;
      if (Math.min(promptToken.length, titleToken.length) >= 5) {
        return promptToken.startsWith(titleToken) || titleToken.startsWith(promptToken);
      }
      return false;
    })) matches += 1;
  }
  return matches / titleTokens.length;
}

function uniqueBest<T>(
  rows: T[],
  score: (row: T) => number,
  minimum = 0.5,
): T | null {
  const ranked = rows
    .map((row) => ({ row, score: score(row) }))
    .filter((item) => item.score >= minimum)
    .sort((a, b) => b.score - a.score);
  if (ranked.length === 0) return rows.length === 1 ? rows[0] : null;
  if (ranked.length > 1 && Math.abs(ranked[0].score - ranked[1].score) < 0.0001) {
    return null;
  }
  return ranked[0].row;
}

function requestedStage(prompt: string, stages: StageRow[]): StageRow | null {
  const value = normalized(prompt);
  const explicit = stages.filter((stage) => {
    const title = normalized(stage.title);
    return title.length >= 3 && value.includes(title);
  });
  if (explicit.length === 1) return explicit[0];

  const aliases: Array<[RegExp, string[]]> = [
    [/(?:готов\w*\s+к\s+вылет|одобрен)/, ["ready"]],
    [/(?:нужн\w*\s+билет|купить\s+билет|билеты)/, ["tickets"]],
    [/(?:жд[её]м\s+документ|запрос\w*\s+документ)/, ["documents"]],
    [/(?:косяк|проблем|провер)/, ["problems"]],
    [/(?:оформлен|принят|заверш)/, ["completed"]],
    [/(?:резерв)/, ["reserve"]],
    [/(?:отказ|отклон)/, ["rejected"]],
    [/(?:новы[йе]|новая)/, ["new"]],
  ];
  for (const [pattern, keys] of aliases) {
    if (!pattern.test(value)) continue;
    const matches = stages.filter((stage) => keys.includes(clean(stage.system_key, 60)));
    if (matches.length === 1) return matches[0];
  }

  return uniqueBest(stages, (stage) => overlapScore(prompt, stage.title), 0.6);
}

export function hrStageMoveIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:перевед|перемест|постав).*(?:кандидат|этап)|(?:кандидат).*(?:этап|перевед|перемест)/.test(value);
}

export async function buildHrStageMove({
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
    return { error: "Изменение этапа кандидата недоступно текущей роли", status: 403 };
  }

  const [{ data: candidateRows, error: candidateError }, { data: stageRows, error: stageError }] =
    await Promise.all([
      client
        .from("recruitment_applications")
        .select("id, full_name, stage_id, object_id")
        .eq("company_id", companyId)
        .is("archived_at", null)
        .order("updated_at", { ascending: false })
        .limit(500),
      client
        .from("recruitment_pipeline_stages")
        .select("id, system_key, title")
        .eq("company_id", companyId)
        .eq("is_active", true)
        .order("sort_order"),
    ]);
  if (candidateError) throw candidateError;
  if (stageError) throw stageError;

  const candidates = (candidateRows ?? []) as CandidateRow[];
  const stages = (stageRows ?? []) as StageRow[];
  const matchingCandidates = candidates.filter((candidate) =>
    nameMatches(prompt, candidate.full_name)
  );
  if (matchingCandidates.length === 0) {
    return { error: "Не нашёл кандидата по имени в голосовой команде", status: 400 };
  }
  if (matchingCandidates.length > 1) {
    return {
      error: `Нашёл несколько кандидатов: ${matchingCandidates.slice(0, 4).map((item) => item.full_name).join(", ")}. Уточни ФИО.`,
      status: 409,
    };
  }

  const stage = requestedStage(prompt, stages);
  if (stage == null) {
    return { error: "Не смог однозначно определить новый этап кандидата", status: 400 };
  }
  const candidate = matchingCandidates[0];
  if (candidate.stage_id === stage.id) {
    return { error: `${candidate.full_name} уже находится на этапе «${stage.title}»`, status: 400 };
  }

  return {
    body: resultWithAction({
      title: "Переход кандидата подготовлен",
      summary: `${candidate.full_name} → «${stage.title}».`,
      highlights: [candidate.full_name, `Новый этап: ${stage.title}`],
      warnings: ["Этап изменится только после подтверждения."],
      date,
      action: {
        id: crypto.randomUUID(),
        type: "move_candidate_stage",
        title: "Изменить этап кандидата",
        button_label: "Проверить переход",
        confirmation_required: true,
        payload: {
          application_id: candidate.id,
          candidate_name: candidate.full_name,
          stage_id: stage.id,
          stage_title: stage.title,
          source_prompt: prompt,
        },
      },
    }),
    status: 200,
  };
}

export function legalDecisionIntent(prompt: string): boolean {
  const value = normalized(prompt);
  const decision = /(?:согласу|одобр|отклон)/.test(value);
  const legal = /(?:юрид|вопрос|риск|решен)/.test(value);
  return decision && legal;
}

function requestedApproval(prompt: string): boolean | null {
  const value = normalized(prompt);
  if (/(?:отклон|не\s+соглас)/.test(value)) return false;
  if (/(?:согласу|одобр|утверд)/.test(value)) return true;
  return null;
}

function decisionComment(prompt: string): string {
  const match = prompt.match(/(?:комментар(?:ий|ием)|потому\s+что)\s*[:\-]?\s*(.+)$/i);
  return clean(match?.[1], 800);
}

export async function buildLegalDecision({
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
  if (!managerRole(role)) {
    return { error: "Юридическое решение может подтверждать только руководитель", status: 403 };
  }
  const approved = requestedApproval(prompt);
  if (approved == null) return { error: "Не понял: согласовать или отклонить?", status: 400 };

  const { data, error } = await client
    .from("legal_matters")
    .select("id, title, manager_question, decision_status, requires_manager_decision")
    .eq("company_id", companyId)
    .eq("requires_manager_decision", true)
    .order("updated_at", { ascending: false })
    .limit(100);
  if (error) throw error;
  const matters = (data ?? []) as MatterRow[];
  if (matters.length === 0) {
    return { error: "Нет юридических вопросов, ожидающих решения руководителя", status: 400 };
  }

  const matter = uniqueBest(
    matters,
    (item) => Math.max(overlapScore(prompt, item.title), overlapScore(prompt, item.manager_question ?? "")),
    0.45,
  );
  if (matter == null) {
    return {
      error: matters.length > 1
        ? "Не понял, какой именно юридический вопрос нужно решить. Назови его точнее."
        : "Не смог определить юридический вопрос.",
      status: 409,
    };
  }

  const comment = decisionComment(prompt);
  return {
    body: resultWithAction({
      title: approved ? "Согласование подготовлено" : "Отклонение подготовлено",
      summary: `${approved ? "Согласовать" : "Отклонить"}: ${matter.title}.`,
      highlights: [matter.title, matter.manager_question ?? ""].filter(Boolean),
      warnings: ["Юридическое решение запишется только после отдельного подтверждения."],
      date,
      action: {
        id: crypto.randomUUID(),
        type: "decide_legal_matter",
        title: approved ? "Согласовать юридический вопрос" : "Отклонить юридический вопрос",
        button_label: approved ? "Проверить согласование" : "Проверить отклонение",
        confirmation_required: true,
        payload: {
          matter_id: matter.id,
          matter_title: matter.title,
          manager_question: matter.manager_question ?? "",
          approved,
          comment,
          source_prompt: prompt,
        },
      },
    }),
    status: 200,
  };
}

const procurementNext: Record<string, string | null> = {
  draft: "submitted",
  submitted: "approved",
  approved: "purchasing",
  purchasing: "ordered",
  ordered: "in_delivery",
  in_delivery: "delivered",
  delivered: null,
  canceled: null,
};

const procurementTitles: Record<string, string> = {
  draft: "Черновик",
  submitted: "На согласовании",
  approved: "Согласовано",
  purchasing: "Закупка",
  ordered: "Заказано",
  in_delivery: "В доставке",
  delivered: "Доставлено",
  canceled: "Отменено",
};

function requestedProcurementStatus(prompt: string, current: string): string | null {
  const value = normalized(prompt);
  if (/(?:отмен|аннулир)/.test(value)) return "canceled";
  const mappings: Array<[RegExp, string]> = [
    [/(?:доставлен|принят\w*\s+достав)/, "delivered"],
    [/(?:в\s+доставк|передан\w*\s+в\s+достав)/, "in_delivery"],
    [/(?:заказан|заказано)/, "ordered"],
    [/(?:начат\w*\s+закуп|в\s+закупк)/, "purchasing"],
    [/(?:согласован|одобрен)/, "approved"],
    [/(?:на\s+согласован|отправ\w*\s+на\s+соглас)/, "submitted"],
  ];
  for (const [pattern, status] of mappings) if (pattern.test(value)) return status;
  if (/(?:следующ|дальше|проведи|переведи)/.test(value)) return procurementNext[current] ?? null;
  return null;
}

export function procurementStatusIntent(prompt: string): boolean {
  const value = normalized(prompt);
  const action = /(?:перевед|провед|отмет|согласу|заказ|достав|отмен|закуп)/.test(value);
  const entity = /(?:заявк|поставк|доставк|снабжен|арматур|бетон|материал)/.test(value);
  return action && entity;
}

export async function buildProcurementStatus({
  client,
  companyId,
  role,
  prompt,
  date,
  requestedObject,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  prompt: string;
  date: string;
  requestedObject: string;
}) {
  if (!procurementRole(role)) {
    return { error: "Изменение снабжения недоступно текущей роли", status: 403 };
  }

  let query = client
    .from("procurement_requests")
    .select("id, title, object_name, status")
    .eq("company_id", companyId)
    .not("status", "in", "(delivered,canceled)")
    .order("updated_at", { ascending: false })
    .limit(200);
  if (requestedObject) query = query.eq("object_name", requestedObject);
  const { data, error } = await query;
  if (error) throw error;
  const requests = (data ?? []) as ProcurementRow[];
  if (requests.length === 0) return { error: "Нет открытых заявок снабжения", status: 400 };

  const request = uniqueBest(requests, (item) => overlapScore(prompt, item.title), 0.35);
  if (request == null) {
    return {
      error: requests.length > 1
        ? "Не смог однозначно определить заявку снабжения. Назови её точнее."
        : "Не смог определить заявку снабжения.",
      status: 409,
    };
  }

  const desired = requestedProcurementStatus(prompt, request.status);
  if (desired == null) {
    return { error: "Не понял новый статус заявки", status: 400 };
  }
  const next = procurementNext[request.status];
  if (desired !== "canceled" && desired !== next) {
    return {
      error: `Нельзя перескочить из «${procurementTitles[request.status] ?? request.status}» сразу в «${procurementTitles[desired] ?? desired}». Сначала нужен следующий этап.`,
      status: 400,
    };
  }

  return {
    body: resultWithAction({
      title: desired === "canceled" ? "Отмена заявки подготовлена" : "Статус снабжения подготовлен",
      summary: `${request.title}: ${procurementTitles[request.status] ?? request.status} → ${procurementTitles[desired] ?? desired}.`,
      highlights: [
        request.title,
        request.object_name ?? "",
        `Новый статус: ${procurementTitles[desired] ?? desired}`,
      ].filter(Boolean),
      warnings: [desired === "canceled"
        ? "Заявка будет отменена только после подтверждения."
        : "Статус изменится только после подтверждения."],
      objectName: request.object_name ?? requestedObject,
      date,
      action: {
        id: crypto.randomUUID(),
        type: "advance_procurement_status",
        title: desired === "canceled" ? "Отменить заявку снабжения" : "Изменить статус снабжения",
        button_label: desired === "canceled" ? "Проверить отмену" : "Проверить статус",
        confirmation_required: true,
        payload: {
          request_id: request.id,
          request_title: request.title,
          object_name: request.object_name ?? "",
          current_status: request.status,
          current_status_title: procurementTitles[request.status] ?? request.status,
          new_status: desired,
          new_status_title: procurementTitles[desired] ?? desired,
          source_prompt: prompt,
        },
      },
    }),
    status: 200,
  };
}
