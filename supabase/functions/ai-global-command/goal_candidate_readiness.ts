import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import type { GlobalVoiceConversationContext } from "./conversation_context.ts";
import {
  actionGoalBody,
  type BuilderResult,
  hrRole,
  maxGoalWrites,
  readOnlyGoalBody,
  resolveGoalObjectScope,
} from "./goal_planner_shared.ts";
import { clean, normalized } from "./shared.ts";

type CandidateDocType =
  | "passport_main"
  | "registration"
  | "snils"
  | "inn"
  | "policy";

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

type FlightRow = {
  application_id: string;
  object_id: string | null;
  departure_at: string;
  arrival_at: string | null;
  origin: string;
  destination: string;
  flight_number: string | null;
  status: string;
};

export type CandidateAssessment = {
  row: CandidateRow;
  flight: FlightRow | null;
  missingDocs: CandidateDocType[];
  unanswered: boolean;
  hasChannel: boolean;
  issueTexts: string[];
  severity: number;
};

type CandidateGoalMode = "all" | "documents" | "responsible" | "communication";

const requiredDocs: CandidateDocType[] = [
  "passport_main",
  "registration",
  "snils",
  "inn",
  "policy",
];

const documentTitles: Record<CandidateDocType, string> = {
  passport_main: "паспорт",
  registration: "регистрация",
  snils: "СНИЛС",
  inn: "ИНН",
  policy: "полис",
};

function candidateGoalMode(prompt: string): CandidateGoalMode {
  const value = normalized(prompt);
  if (/(?:только|лишь).*(?:документ|паспорт|регистрац|снилс|инн|полис)|что\s+с\s+документ/.test(value)) {
    return "documents";
  }
  if (/(?:только|лишь).*(?:ответствен)|что\s+с\s+ответствен/.test(value)) {
    return "responsible";
  }
  if (/(?:только|лишь).*(?:связ|ответ|сообщен|канал)|что\s+со\s+связ/.test(value)) {
    return "communication";
  }
  return "all";
}

function wantsPreparedMessages(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:подготов.*(?:все|все\s+что|сообщ)|сделай\s+что\s+мож|напомни\s+им|подготовь\s+сообщ|напиши\s+им)/.test(value);
}

function flightGoal(prompt: string): boolean {
  return /(?:вылет|вылета|улета|рейс|заезд|прилет|билет)/.test(normalized(prompt));
}

function dayWindow(date: string): { start: string; end: string } {
  const start = `${date}T00:00:00.000Z`;
  const next = new Date(start);
  next.setUTCDate(next.getUTCDate() + 1);
  return { start, end: next.toISOString() };
}

async function loadDocuments(
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
    if (!requiredDocs.includes(type)) continue;
    const set = result.get(applicationId) ?? new Set<CandidateDocType>();
    set.add(type);
    result.set(applicationId, set);
  }
  return result;
}

async function loadMessageState(
  client: SupabaseClient,
  companyId: string,
  ids: string[],
): Promise<Map<string, { inbound: number; outbound: number }>> {
  const result = new Map<string, { inbound: number; outbound: number }>();
  if (ids.length === 0) return result;
  const { data, error } = await client
    .from("recruitment_messages")
    .select("application_id, direction, created_at")
    .eq("company_id", companyId)
    .in("application_id", ids)
    .in("direction", ["inbound", "outbound"])
    .order("created_at", { ascending: true })
    .limit(10000);
  if (error) throw error;
  for (const row of data ?? []) {
    const applicationId = clean((row as any).application_id, 80);
    const time = Date.parse(clean((row as any).created_at, 60));
    if (!applicationId || !Number.isFinite(time)) continue;
    const current = result.get(applicationId) ?? { inbound: 0, outbound: 0 };
    const direction = clean((row as any).direction, 20);
    if (direction === "inbound") current.inbound = Math.max(current.inbound, time);
    if (direction === "outbound") current.outbound = Math.max(current.outbound, time);
    result.set(applicationId, current);
  }
  return result;
}

async function loadFlights(
  client: SupabaseClient,
  companyId: string,
  ids: string[],
  date: string,
): Promise<Map<string, FlightRow>> {
  const result = new Map<string, FlightRow>();
  if (ids.length === 0) return result;
  const window = dayWindow(date);
  const { data, error } = await client
    .from("recruitment_flights")
    .select("application_id, object_id, departure_at, arrival_at, origin, destination, flight_number, status")
    .eq("company_id", companyId)
    .in("application_id", ids)
    .gte("departure_at", window.start)
    .lt("departure_at", window.end)
    .neq("status", "cancelled")
    .order("departure_at", { ascending: true })
    .limit(1000);
  if (error) throw error;
  for (const raw of data ?? []) {
    const row = raw as FlightRow;
    const applicationId = clean(row.application_id, 80);
    if (applicationId && !result.has(applicationId)) result.set(applicationId, row);
  }
  return result;
}

function hasCandidateChannel(row: CandidateRow): boolean {
  const source = clean(row.source, 30).toLowerCase();
  if (source === "telegram") return clean(row.external_chat_id, 120).length > 0;
  if (source === "max") return clean(row.external_user_id, 120).length > 0;
  return false;
}

function assessCandidate(
  row: CandidateRow,
  docs: Map<string, Set<CandidateDocType>>,
  messages: Map<string, { inbound: number; outbound: number }>,
  flight: FlightRow | null,
): CandidateAssessment {
  const present = docs.get(row.id) ?? new Set<CandidateDocType>();
  const missingDocs = requiredDocs.filter((type) => !present.has(type));
  const state = messages.get(row.id) ?? { inbound: 0, outbound: 0 };
  const unanswered = state.outbound > 0 && state.outbound > state.inbound;
  const hasChannel = hasCandidateChannel(row);
  const issueTexts: string[] = [];
  let severity = 0;

  if (missingDocs.length > 0) {
    issueTexts.push(`не хватает: ${missingDocs.map((type) => documentTitles[type]).join(", ")}`);
    severity += missingDocs.includes("passport_main") ? 5 : 2;
    severity += Math.max(0, missingDocs.length - 1);
  }
  if (!clean(row.responsible_user_id, 80)) {
    issueTexts.push("не назначен ответственный");
    severity += 3;
  }
  if (unanswered) {
    issueTexts.push("нет ответа на последнее исходящее сообщение");
    severity += 1;
  }
  if (!hasChannel) {
    issueTexts.push("нет подтверждённого Telegram/MAX-канала");
    severity += 2;
  }

  return { row, flight, missingDocs, unanswered, hasChannel, issueTexts, severity };
}

export async function loadCandidateReadiness({
  client,
  companyId,
  objectId,
  date,
  flightOnly,
}: {
  client: SupabaseClient;
  companyId: string;
  objectId?: string;
  date: string;
  flightOnly: boolean;
}): Promise<CandidateAssessment[]> {
  let query = client
    .from("recruitment_applications")
    .select("id, full_name, object_id, responsible_user_id, source, external_user_id, external_chat_id, status, stage_id, ready_date")
    .eq("company_id", companyId)
    .is("archived_at", null)
    .eq("is_test_record", false)
    .order("updated_at", { ascending: false })
    .limit(500);
  if (objectId) query = query.eq("object_id", objectId);
  const { data, error } = await query;
  if (error) throw error;
  const candidates = (data ?? []) as CandidateRow[];
  const ids = candidates.map((row) => row.id);
  const [docs, messages, flights] = await Promise.all([
    loadDocuments(client, companyId, ids),
    loadMessageState(client, companyId, ids),
    loadFlights(client, companyId, ids, date),
  ]);

  return candidates
    .filter((row) => !flightOnly || flights.has(row.id))
    .map((row) => assessCandidate(row, docs, messages, flights.get(row.id) ?? null))
    .sort((left, right) => {
      if (left.severity !== right.severity) return right.severity - left.severity;
      const leftFlight = clean(left.flight?.departure_at, 60);
      const rightFlight = clean(right.flight?.departure_at, 60);
      if (leftFlight !== rightFlight) return leftFlight.localeCompare(rightFlight);
      return left.row.full_name.localeCompare(right.row.full_name, "ru");
    });
}

function filteredAssessments(
  assessments: CandidateAssessment[],
  mode: CandidateGoalMode,
): CandidateAssessment[] {
  if (mode === "documents") return assessments.filter((item) => item.missingDocs.length > 0);
  if (mode === "responsible") return assessments.filter((item) => !clean(item.row.responsible_user_id, 80));
  if (mode === "communication") return assessments.filter((item) => item.unanswered || !item.hasChannel);
  return assessments.filter((item) => item.issueTexts.length > 0);
}

function candidateLabel(item: CandidateAssessment): string {
  const route = item.flight
    ? `${clean(item.flight.origin, 80)} → ${clean(item.flight.destination, 80)}`
    : "без рейса на выбранную дату";
  return `${item.row.full_name} • ${route} • ${item.issueTexts.join("; ")}`;
}

function reminderText(item: CandidateAssessment, date: string): string {
  const missing = item.missingDocs.map((type) => documentTitles[type]).join(", ");
  return `Для подготовки к вылету на ${date} пришлите, пожалуйста, недостающие документы: ${missing}.`;
}

function candidateMessageAction(item: CandidateAssessment, date: string) {
  return {
    id: crypto.randomUUID(),
    type: "send_candidate_message",
    title: `Напомнить о документах: ${item.row.full_name}`,
    button_label: "Проверить сообщение",
    confirmation_required: true,
    payload: {
      application_id: item.row.id,
      candidate_name: item.row.full_name,
      source: clean(item.row.source, 30).toLowerCase(),
      body: reminderText(item, date),
      source_prompt: "voice_goal_planner_v16_candidate_readiness",
    },
  };
}

export async function buildCandidateReadinessGoal({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
  date,
  conversationContext,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
  date: string;
  conversationContext: GlobalVoiceConversationContext;
}): Promise<BuilderResult> {
  if (!hrRole(role)) {
    return { error: "Диагностика готовности кандидатов недоступна текущей роли", status: 403 };
  }

  const inherited = conversationContext.topic === "goal_candidate_readiness";
  const effectiveDate = inherited && conversationContext.date
    ? conversationContext.date
    : date;
  const sourcePrompt = inherited && conversationContext.prompt
    ? `${conversationContext.prompt}. ${prompt}`
    : prompt;
  const objectScope = await resolveGoalObjectScope({
    client,
    companyId,
    role,
    assignedObject,
    requestedObject: requestedObject || (inherited ? conversationContext.objectName : ""),
    prompt: sourcePrompt,
  });
  if (objectScope && "error" in objectScope) return objectScope;

  const flightOnly = flightGoal(sourcePrompt) || inherited;
  const assessments = await loadCandidateReadiness({
    client,
    companyId,
    objectId: objectScope?.id,
    date: effectiveDate,
    flightOnly,
  });
  const mode = candidateGoalMode(prompt);
  const issues = filteredAssessments(assessments, mode);
  const checks = mode === "documents"
    ? ["candidate_documents"]
    : mode === "responsible"
    ? ["candidate_responsible"]
    : mode === "communication"
    ? ["candidate_messages", "candidate_channels"]
    : ["candidate_flights", "candidate_documents", "candidate_responsible", "candidate_messages", "candidate_channels"];
  const objectName = objectScope?.name ?? "";
  const departures = assessments.filter((item) => item.flight != null).length;
  const ready = assessments.filter((item) => item.issueTexts.length === 0).length;
  const summary = flightOnly
    ? `На ${effectiveDate} найдено вылетов кандидатов: ${departures}. Без замечаний: ${ready}. С проблемами по выбранным проверкам: ${issues.length}.`
    : `Проверено кандидатов: ${assessments.length}. Без замечаний: ${ready}. С проблемами по выбранным проверкам: ${issues.length}.`;
  const nextSteps: string[] = [];
  if (issues.some((item) => item.missingDocs.length > 0)) {
    nextSteps.push("Можно сказать «подготовь сообщения им» — помощник подготовит напоминания только тем, у кого есть подтверждённый Telegram/MAX-канал.");
  }
  if (issues.some((item) => !clean(item.row.responsible_user_id, 80))) {
    nextSteps.push("Для кандидатов без ответственного назови конкретного ответственного — назначение по-прежнему требует явного выбора человека.");
  }
  if (issues.some((item) => !item.hasChannel)) {
    nextSteps.push("Кандидатам без подтверждённого канала сообщение автоматически не готовится: сначала нужно связать Telegram/MAX.");
  }

  const wantsMessages = wantsPreparedMessages(prompt);
  if (wantsMessages) {
    const messageTargets = issues.filter((item) => item.missingDocs.length > 0 && item.hasChannel);
    if (messageTargets.length > maxGoalWrites) {
      return {
        body: readOnlyGoalBody({
          kind: "candidate_readiness",
          title: "Готовность к вылету проверена",
          summary: `${summary} Для напоминаний подходит ${messageTargets.length}, но один пакет ограничен ${maxGoalWrites}.`,
          highlights: issues.map(candidateLabel),
          warnings: [`Не создаю частичный пакет молча: сузь группу до ${maxGoalWrites} кандидатов.`],
          nextSteps: ["Например: «подготовь сообщения первым двенадцати»."],
          date: effectiveDate,
          objectName,
          prompt: sourcePrompt,
          conversationTopic: "goal_candidate_readiness",
          conversationMode: mode,
          checks,
          issueCount: issues.length,
          affectedCount: assessments.length,
        }),
        status: 200,
      };
    }
    if (messageTargets.length > 0) {
      const actions = messageTargets.map((item) => candidateMessageAction(item, effectiveDate));
      return {
        body: actionGoalBody({
          kind: "candidate_readiness",
          title: "Готовность проверена, напоминания подготовлены",
          summary: `${summary} Подготовлено сообщений о недостающих документах: ${actions.length}.`,
          highlights: messageTargets.map((item) => `${item.row.full_name} → ${reminderText(item, effectiveDate)}`),
          warnings: [
            "Сообщения ещё не отправлены: каждое действие проходит штатное подтверждение и аудит.",
            "Ответственный, этап кандидата и данные рейса автоматически не меняются.",
          ],
          nextSteps,
          date: effectiveDate,
          objectName,
          checks,
          issueCount: issues.length,
          affectedCount: assessments.length,
          actions,
        }),
        status: 200,
      };
    }
  }

  return {
    body: readOnlyGoalBody({
      kind: "candidate_readiness",
      title: flightOnly ? "Готовность кандидатов к вылету" : "Готовность кандидатов",
      summary,
      highlights: issues.length > 0 ? issues.map(candidateLabel) : ["По выбранным проверкам проблем не найдено."],
      warnings: [
        "Это снимок текущих данных. Помощник не считает отсутствие ответа или канала доказательством отказа кандидата.",
      ],
      nextSteps,
      date: effectiveDate,
      objectName,
      prompt: sourcePrompt,
      conversationTopic: "goal_candidate_readiness",
      conversationMode: mode,
      checks,
      issueCount: issues.length,
      affectedCount: assessments.length,
    }),
    status: 200,
  };
}
