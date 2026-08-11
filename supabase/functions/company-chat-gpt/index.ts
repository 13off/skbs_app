import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonMap = Record<string, unknown>;
type ChatRow = {
  id: string;
  company_id: string;
  sender_user_id: string | null;
  sender_name: string;
  kind: string;
  channel_kind: string;
  peer_user_id: string | null;
  thread_key: string;
  body: string;
  created_at: string;
  deleted_at: string | null;
  ai_payload?: JsonMap | null;
};

const CHATGPT_CUTOVER = "2026-08-11T11:19:00.000Z";
const MAX_TOOL_ROUNDS = 6;

const APP_KNOWLEDGE = [
  "Ты ChatGPT внутри AppСтрой — рабочего приложения строительной компании.",
  "Работай как полноценный агент приложения: понимай цель пользователя, сам выбирай нужные инструменты, читай актуальные данные и подготавливай действия.",
  "В AppСтрой есть объекты, сотрудники, табель и смены, выплаты/авансы/остатки/чеки, задачи, цели, кандидаты, HR-задачи, документы, билеты и вылеты, снабжение, поставщики, юридический блок, чат, уведомления, профиль, рабочий день и геолокация.",
  "Для точечных команд и штатных действий используй appstroy_command. Для свободного анализа живых данных используй appstroy_data. Для XLSX используй appstroy_export.",
  "Никогда не выдумывай ФИО, ID, суммы, смены, статусы или записи компании. Если нужны факты — получи их инструментом.",
  "Если задача состоит из нескольких шагов, вызывай инструменты последовательно до достижения цели. Можно сначала найти данные, затем подготовить одно или несколько действий и выгрузку.",
  "Если пользователь просит что-то изменить, создать, назначить, отправить, перевести, отметить, сохранить или удалить — подготовь штатное действие AppСтрой. Окончательное изменение выполняется после отдельного подтверждения в интерфейсе.",
  "Если пользователь просит таблицу/Excel/XLSX/выгрузку/файл — используй appstroy_export, а не отправляй его вручную в раздел приложения.",
  "Поддерживаемые XLSX: выплаты, табель, сотрудники, задачи, кандидаты, снабжение, поставщики, вылеты.",
  "Короткие продолжения вроде «сам сделай», «эту таблицу», «за тот месяц», «тогда скачай», «ему поставь две смены» разрешай по истории диалога.",
  "Для сложного анализа можешь запросить несколько наборов данных через appstroy_data и самостоятельно сопоставить их.",
  "Если подготовлено действие или выгрузка — скажи коротко, что всё готово и нужно нажать кнопку под сообщением. Не предлагай ручной обходной путь.",
  "Для общих вопросов, текстов, идей и объяснений отвечай напрямую без инструментов.",
  "Не раскрывай внутренние роутеры, Edge Functions и техническую реализацию, если пользователь сам об этом не спрашивает.",
  "Отвечай по-русски, естественно и по делу.",
].join("\n");

const APP_COMMAND_TOOL = {
  type: "function",
  name: "appstroy_command",
  description: "Прочитать актуальные данные или подготовить штатное действие AppСтрой. Особенно используй для CRUD, навигации, HR, табеля, выплат, задач, снабжения, юридических действий и сообщений.",
  parameters: {
    type: "object",
    properties: {
      prompt: {
        type: "string",
        description: "Самостоятельная полная команда. Включи имена, даты, суммы, объект и смысл, даже если они были в предыдущих сообщениях.",
      },
    },
    required: ["prompt"],
    additionalProperties: false,
  },
  strict: true,
};

const APP_EXPORT_TOOL = {
  type: "function",
  name: "appstroy_export",
  description: "Подготовить кнопку, которая сформирует и скачает XLSX из актуальных данных AppСтрой.",
  parameters: {
    type: "object",
    properties: {
      report_type: {
        type: "string",
        enum: ["payments", "timesheet", "employees", "tasks", "candidates", "procurement", "suppliers", "flights"],
      },
      month: { type: "string", description: "YYYY-MM или пустая строка, если месячный фильтр не нужен." },
      object_name: { type: "string", description: "Название объекта или пустая строка для доступного общего scope." },
    },
    required: ["report_type", "month", "object_name"],
    additionalProperties: false,
  },
  strict: true,
};

const APP_DATA_TOOL = {
  type: "function",
  name: "appstroy_data",
  description: "Получить структурированные актуальные строки из разрешённого раздела AppСтрой для анализа, сопоставления и принятия решения. Чтение идёт с правами текущего пользователя.",
  parameters: {
    type: "object",
    properties: {
      dataset: {
        type: "string",
        enum: [
          "employees", "attendance", "payments", "tasks", "candidates", "flights",
          "procurement", "suppliers", "objects", "milestones", "legal_matters",
          "legal_documents", "recruitment_tasks", "documents"
        ],
      },
      month: { type: "string", description: "YYYY-MM или пустая строка." },
      date_from: { type: "string", description: "YYYY-MM-DD или пустая строка." },
      date_to: { type: "string", description: "YYYY-MM-DD или пустая строка." },
      object_name: { type: "string", description: "Название объекта или пустая строка." },
      status: { type: "string", description: "Статус для фильтра или пустая строка." },
      search: { type: "string", description: "ФИО/название/ключевое слово или пустая строка." },
      limit: { type: "number", description: "Сколько строк вернуть, обычно 20-80, максимум 150." },
    },
    required: ["dataset", "month", "date_from", "date_to", "object_name", "status", "search", "limit"],
    additionalProperties: false,
  },
  strict: true,
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}
function clean(value: unknown, max = 6000): string {
  return String(value ?? "").trim().slice(0, max);
}
function mapValue(value: unknown): JsonMap {
  return value && typeof value === "object" && !Array.isArray(value) ? value as JsonMap : {};
}
function serviceKey(): string {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, string>;
      return parsed.default ?? Object.values(parsed)[0] ?? "";
    } catch (_) {}
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}
function publishableKey(): string {
  const legacy = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
  if (legacy) return legacy;
  const direct = Deno.env.get("SUPABASE_PUBLISHABLE_KEY")?.trim() ?? "";
  if (direct) return direct;
  const modern = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, string>;
      return parsed.default ?? Object.values(parsed)[0] ?? "";
    } catch (_) {}
  }
  return "";
}
function outputText(payload: any): string {
  if (typeof payload?.output_text === "string") return payload.output_text.trim();
  const output = Array.isArray(payload?.output) ? payload.output : [];
  const parts: string[] = [];
  for (const item of output) {
    if (item?.type !== "message" || !Array.isArray(item?.content)) continue;
    for (const part of item.content) {
      if (part?.type === "output_text" && typeof part?.text === "string" && part.text.trim()) {
        parts.push(part.text.trim());
      }
    }
  }
  return parts.join("\n\n").trim();
}
function todayMsk(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Moscow", year: "numeric", month: "2-digit", day: "2-digit",
  }).format(new Date());
}
function monthBounds(value: string): { start: string; end: string } | null {
  const match = /^(20\d{2})-(0[1-9]|1[0-2])$/.exec(value.trim());
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const start = `${year}-${String(month).padStart(2, "0")}-01`;
  const next = month === 12 ? `${year + 1}-01-01` : `${year}-${String(month + 1).padStart(2, "0")}-01`;
  return { start, end: next };
}
function safeLimit(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 50;
  return Math.max(1, Math.min(150, Math.round(parsed)));
}
function ilike(value: string): string {
  return `%${value.replace(/[%_]/g, " ").trim()}%`;
}
function conversationContext(recent: ChatRow[], source: ChatRow): JsonMap {
  const prior = recent.filter((item) => item.id !== source.id);
  const lastAssistant = [...prior].reverse().find((item) => item.kind === "assistant");
  const payload = mapValue(lastAssistant?.ai_payload);
  const conversation = mapValue(payload.conversation);
  const memory = mapValue(payload.agent_memory);
  const previousUser = [...prior].reverse().find((item) => item.kind === "user");
  const result: JsonMap = { ...memory };
  for (const key of ["topic", "query_mode", "object_name", "date", "month", "last_report_type"]) {
    const value = clean(conversation[key] ?? memory[key], 180);
    if (value) result[key] = value;
  }
  const previousPrompt = clean(conversation.prompt, 1200) || clean(previousUser?.body, 1200);
  if (previousPrompt) result.prompt = previousPrompt;
  return result;
}
async function invokeAppStroy(args: {
  supabaseUrl: string; publishable: string; authorization: string; companyId: string;
  objectName: string; prompt: string; context: JsonMap;
}): Promise<{ data: JsonMap; status: number }> {
  const response = await fetch(`${args.supabaseUrl}/functions/v1/ai-global-command`, {
    method: "POST",
    headers: { Authorization: args.authorization, apikey: args.publishable, "Content-Type": "application/json" },
    body: JSON.stringify({
      company_id: args.companyId,
      object_name: args.objectName || null,
      date: todayMsk(),
      prompt: args.prompt,
      conversation_context: args.context,
      input_mode: "chatgpt",
    }),
  });
  return { data: await response.json().catch(() => ({})) as JsonMap, status: response.status };
}
async function openAiResponse(args: { apiKey: string; model: string; input: unknown[] }) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25_000);
  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${args.apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: args.model,
        input: args.input,
        tools: [APP_COMMAND_TOOL, APP_DATA_TOOL, APP_EXPORT_TOOL],
        tool_choice: "auto",
        store: false,
      }),
      signal: controller.signal,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload?.error?.message || `OpenAI API error ${response.status}`);
    return payload;
  } finally {
    clearTimeout(timer);
  }
}
function parseArgs(call: any): JsonMap {
  try { return mapValue(JSON.parse(String(call?.arguments ?? "{}"))); } catch (_) { return {}; }
}
function parseToolPrompt(call: any, fallback: string): string {
  return clean(parseArgs(call).prompt, 4000) || fallback;
}
function actionLabel(type: string): string {
  const labels: Record<string, string> = {
    create_task_draft: "Проверить и создать задачу",
    prepare_timesheet_correction: "Проверить и сохранить табель",
    bulk_timesheet_update: "Проверить и сохранить табель",
    prepare_payment: "Проверить и сохранить выплату",
    prepare_document: "Проверить и скачать документ",
    prepare_work_act: "Проверить и сформировать акт",
    create_employee_draft: "Проверить и добавить сотрудника",
    prepare_employee_update: "Проверить и сохранить сотрудника",
    create_procurement_request: "Проверить и создать заявку",
    create_legal_matter: "Проверить и создать вопрос",
    assign_candidate_responsible: "Проверить и назначить",
    send_candidate_message: "Проверить и отправить сообщение",
    move_candidate_stage: "Проверить и перевести кандидата",
    decide_legal_matter: "Проверить решение",
    advance_procurement_status: "Проверить и изменить статус",
    manage_object: "Проверить изменение объекта",
    manage_milestone: "Проверить изменение цели",
    manage_supplier: "Проверить изменение поставщика",
    manage_flight: "Проверить действие с вылетом",
    send_company_chat_message: "Проверить и отправить сообщение",
    create_reminder: "Проверить и создать напоминание",
    download_timesheet_excel: "Скачать таблицу табеля",
    download_payment_report: "Скачать таблицу выплат",
    download_appstroy_table: "Скачать XLSX",
  };
  return labels[type] ?? "Проверить действие";
}
function normalizeAction(raw: JsonMap, sourceMessageId: string): JsonMap {
  const type = clean(raw.type, 100);
  if (!type) return {};
  const safeNoSecondConfirm = new Set(["open_screen", "open_candidate_detail", "download_timesheet_excel", "download_payment_report", "download_appstroy_table"]);
  return {
    ...raw,
    id: clean(raw.id, 160) || `chatgpt-action-${sourceMessageId}-${type}`,
    type,
    title: clean(raw.title, 240) || "Действие AppСтрой",
    button_label: clean(raw.button_label, 120) || actionLabel(type),
    confirmation_required: safeNoSecondConfirm.has(type) ? false : raw.confirmation_required !== false,
    payload: mapValue(raw.payload),
  };
}
function appendAction(target: JsonMap[], raw: JsonMap, sourceMessageId: string) {
  const normalized = normalizeAction(raw, sourceMessageId);
  if (!Object.keys(normalized).length) return;
  if (clean(normalized.type) === "voice_compound_batch") {
    const payload = mapValue(normalized.payload);
    const nested = Array.isArray(payload.actions) ? payload.actions : [];
    for (const item of nested) appendAction(target, mapValue(item), sourceMessageId);
    return;
  }
  target.push(normalized);
}
function finalAction(actions: JsonMap[], sourceMessageId: string): JsonMap {
  const seen = new Set<string>();
  const unique: JsonMap[] = [];
  for (const action of actions) {
    const key = `${clean(action.type)}:${JSON.stringify(mapValue(action.payload))}`;
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(action);
  }
  if (unique.length === 0) return {};
  if (unique.length === 1) return unique[0];
  return {
    id: `chatgpt-plan-${sourceMessageId}`,
    type: "voice_compound_batch",
    title: `План ChatGPT: ${unique.length} действий`,
    button_label: `Проверить и выполнить ${unique.length} действий`,
    confirmation_required: false,
    payload: { actions: unique, source: "chatgpt_agent_plan" },
  };
}
function parseExport(call: any, sourceMessageId: string): JsonMap {
  const raw = parseArgs(call);
  const reportType = clean(raw.report_type, 40).toLowerCase();
  const month = clean(raw.month, 20);
  const objectName = clean(raw.object_name, 180);
  const allowed = new Set(["payments", "timesheet", "employees", "tasks", "candidates", "procurement", "suppliers", "flights"]);
  if (!allowed.has(reportType)) return {};
  if (reportType === "payments") {
    return normalizeAction({
      id: `chatgpt-export-payments-${sourceMessageId}`, type: "download_payment_report",
      title: "Скачать таблицу выплат", button_label: "Скачать таблицу выплат", confirmation_required: false,
      payload: { month, object_name: objectName || null, source: "chatgpt_export_tool" },
    }, sourceMessageId);
  }
  if (reportType === "timesheet") {
    return normalizeAction({
      id: `chatgpt-export-timesheet-${sourceMessageId}`, type: "download_timesheet_excel",
      title: "Скачать таблицу табеля", button_label: "Скачать таблицу табеля", confirmation_required: false,
      payload: { month, object_name: objectName || null, source: "chatgpt_export_tool" },
    }, sourceMessageId);
  }
  return normalizeAction({
    id: `chatgpt-export-${reportType}-${sourceMessageId}`, type: "download_appstroy_table",
    title: "Скачать XLSX из AppСтрой", button_label: "Скачать XLSX", confirmation_required: false,
    payload: { report_type: reportType, month, object_name: objectName || null, source: "chatgpt_export_tool" },
  }, sourceMessageId);
}
async function objectMap(client: any, companyId: string, ids?: string[]): Promise<Record<string, string>> {
  let query: any = client.from("objects").select("id,name").eq("company_id", companyId);
  if (ids && ids.length) query = query.in("id", ids);
  const { data, error } = await query.limit(1000);
  if (error) return {};
  return Object.fromEntries((data ?? []).map((r: any) => [String(r.id ?? ""), String(r.name ?? "")]));
}
async function employeeMap(client: any, companyId: string, ids: string[]): Promise<Record<string, any>> {
  if (!ids.length) return {};
  const { data, error } = await client.from("employees").select("id,fio,position,object_name,daily_rate,is_active").eq("company_id", companyId).in("id", ids).limit(1000);
  if (error) return {};
  return Object.fromEntries((data ?? []).map((r: any) => [String(r.id ?? ""), r]));
}
async function candidateMap(client: any, companyId: string, ids: string[]): Promise<Record<string, any>> {
  if (!ids.length) return {};
  const { data, error } = await client.from("recruitment_applications").select("id,full_name,phone,position_title,status,object_id").eq("company_id", companyId).in("id", ids).limit(1000);
  if (error) return {};
  return Object.fromEntries((data ?? []).map((r: any) => [String(r.id ?? ""), r]));
}
async function queryData(client: any, companyId: string, raw: JsonMap): Promise<JsonMap> {
  const dataset = clean(raw.dataset, 60).toLowerCase();
  const month = clean(raw.month, 20);
  const dateFrom = clean(raw.date_from, 20);
  const dateTo = clean(raw.date_to, 20);
  const objectName = clean(raw.object_name, 180);
  const status = clean(raw.status, 100);
  const search = clean(raw.search, 180);
  const limit = safeLimit(raw.limit);
  const monthRange = monthBounds(month);
  try {
    if (dataset === "employees") {
      let q: any = client.from("employees").select("id,fio,position,phone,object_name,daily_rate,is_active,comment,created_at").eq("company_id", companyId).is("archived_at", null);
      if (objectName) q = q.eq("object_name", objectName);
      if (search) q = q.ilike("fio", ilike(search));
      const { data, error } = await q.order("fio").limit(limit); if (error) throw error;
      return { dataset, rows: data ?? [], row_count: (data ?? []).length, limit };
    }
    if (dataset === "attendance") {
      let q: any = client.from("attendance").select("work_date,employee_id,object_name,status,shifts,hours,comment").eq("company_id", companyId).is("deleted_at", null);
      if (objectName) q = q.eq("object_name", objectName);
      if (monthRange) q = q.gte("work_date", monthRange.start).lt("work_date", monthRange.end);
      if (dateFrom) q = q.gte("work_date", dateFrom); if (dateTo) q = q.lte("work_date", dateTo);
      if (status) q = q.eq("status", status);
      const { data, error } = await q.order("work_date", { ascending: false }).limit(limit); if (error) throw error;
      const rows = data ?? []; const ids = [...new Set(rows.map((r: any) => String(r.employee_id ?? "")).filter(Boolean))] as string[];
      const employees = await employeeMap(client, companyId, ids);
      const enriched = rows.map((r: any) => ({ ...r, employee_name: employees[String(r.employee_id ?? "")]?.fio ?? "", position: employees[String(r.employee_id ?? "")]?.position ?? "" }));
      const filtered = search ? enriched.filter((r: any) => String(r.employee_name).toLowerCase().includes(search.toLowerCase())) : enriched;
      return { dataset, rows: filtered, row_count: filtered.length, limit };
    }
    if (dataset === "payments") {
      let q: any = client.from("payments").select("payment_date,employee_id,period_year,period_month,amount,payment_type,comment,created_at").eq("company_id", companyId).is("deleted_at", null);
      if (monthRange) { const [y, m] = month.split("-").map(Number); q = q.eq("period_year", y).eq("period_month", m); }
      if (dateFrom) q = q.gte("payment_date", dateFrom); if (dateTo) q = q.lte("payment_date", dateTo);
      const { data, error } = await q.order("payment_date", { ascending: false }).limit(limit); if (error) throw error;
      const rows = data ?? []; const ids = [...new Set(rows.map((r: any) => String(r.employee_id ?? "")).filter(Boolean))] as string[];
      const employees = await employeeMap(client, companyId, ids);
      let enriched = rows.map((r: any) => ({ ...r, employee_name: employees[String(r.employee_id ?? "")]?.fio ?? "", position: employees[String(r.employee_id ?? "")]?.position ?? "", object_name: employees[String(r.employee_id ?? "")]?.object_name ?? "" }));
      if (objectName) enriched = enriched.filter((r: any) => r.object_name === objectName);
      if (search) enriched = enriched.filter((r: any) => String(r.employee_name).toLowerCase().includes(search.toLowerCase()));
      return { dataset, rows: enriched, row_count: enriched.length, limit };
    }
    if (dataset === "tasks") {
      let q: any = client.from("tasks").select("id,task_date,object_name,axes,work,status,not_done_comment,created_at").eq("company_id", companyId).is("deleted_at", null).eq("is_draft", false);
      if (objectName) q = q.eq("object_name", objectName); if (status) q = q.eq("status", status); if (search) q = q.ilike("work", ilike(search));
      if (monthRange) q = q.gte("task_date", monthRange.start).lt("task_date", monthRange.end); if (dateFrom) q = q.gte("task_date", dateFrom); if (dateTo) q = q.lte("task_date", dateTo);
      const { data, error } = await q.order("task_date", { ascending: false }).limit(limit); if (error) throw error;
      return { dataset, rows: data ?? [], row_count: (data ?? []).length, limit };
    }
    if (dataset === "candidates") {
      let q: any = client.from("recruitment_applications").select("id,full_name,phone,citizenship,position_title,ready_date,status,source,created_at,object_id,stage_id,responsible_user_id").eq("company_id", companyId).is("archived_at", null).eq("is_test_record", false);
      if (status) q = q.eq("status", status); if (search) q = q.ilike("full_name", ilike(search));
      if (monthRange) q = q.gte("created_at", `${monthRange.start}T00:00:00Z`).lt("created_at", `${monthRange.end}T00:00:00Z`);
      const { data, error } = await q.order("created_at", { ascending: false }).limit(limit); if (error) throw error;
      const rows = data ?? []; const objectIds = [...new Set(rows.map((r: any) => String(r.object_id ?? "")).filter(Boolean))] as string[]; const objects = await objectMap(client, companyId, objectIds);
      const stageIds = [...new Set(rows.map((r: any) => String(r.stage_id ?? "")).filter(Boolean))] as string[]; let stages: Record<string, string> = {};
      if (stageIds.length) { const { data: sd } = await client.from("recruitment_pipeline_stages").select("id,title").eq("company_id", companyId).in("id", stageIds).limit(1000); stages = Object.fromEntries((sd ?? []).map((r: any) => [String(r.id ?? ""), String(r.title ?? "")])); }
      let enriched = rows.map((r: any) => ({ ...r, object_name: objects[String(r.object_id ?? "")] ?? "", stage_title: stages[String(r.stage_id ?? "")] ?? "" }));
      if (objectName) enriched = enriched.filter((r: any) => r.object_name === objectName);
      return { dataset, rows: enriched, row_count: enriched.length, limit };
    }
    if (dataset === "flights") {
      let q: any = client.from("recruitment_flights").select("id,application_id,object_id,departure_at,arrival_at,origin,destination,flight_number,status,ticket_original_name,notes").eq("company_id", companyId);
      if (status) q = q.eq("status", status); if (monthRange) q = q.gte("departure_at", `${monthRange.start}T00:00:00Z`).lt("departure_at", `${monthRange.end}T00:00:00Z`);
      if (dateFrom) q = q.gte("departure_at", `${dateFrom}T00:00:00Z`); if (dateTo) q = q.lte("departure_at", `${dateTo}T23:59:59Z`);
      const { data, error } = await q.order("departure_at", { ascending: false }).limit(limit); if (error) throw error;
      const rows = data ?? []; const appIds = [...new Set(rows.map((r: any) => String(r.application_id ?? "")).filter(Boolean))] as string[]; const candidates = await candidateMap(client, companyId, appIds);
      const objectIds = [...new Set(rows.map((r: any) => String(r.object_id ?? "")).filter(Boolean))] as string[]; const objects = await objectMap(client, companyId, objectIds);
      let enriched = rows.map((r: any) => ({ ...r, candidate_name: candidates[String(r.application_id ?? "")]?.full_name ?? "", candidate_phone: candidates[String(r.application_id ?? "")]?.phone ?? "", object_name: objects[String(r.object_id ?? "")] ?? "" }));
      if (objectName) enriched = enriched.filter((r: any) => r.object_name === objectName); if (search) enriched = enriched.filter((r: any) => String(r.candidate_name).toLowerCase().includes(search.toLowerCase()));
      return { dataset, rows: enriched, row_count: enriched.length, limit };
    }
    if (dataset === "procurement") {
      let q: any = client.from("procurement_requests").select("id,title,object_name,status,priority,needed_by,expected_delivery_at,total_amount,invoice_number,comment,created_at").eq("company_id", companyId);
      if (objectName) q = q.eq("object_name", objectName); if (status) q = q.eq("status", status); if (search) q = q.ilike("title", ilike(search));
      if (monthRange) q = q.gte("created_at", `${monthRange.start}T00:00:00Z`).lt("created_at", `${monthRange.end}T00:00:00Z`);
      const { data, error } = await q.order("created_at", { ascending: false }).limit(limit); if (error) throw error;
      return { dataset, rows: data ?? [], row_count: (data ?? []).length, limit };
    }
    if (dataset === "suppliers") {
      let q: any = client.from("procurement_suppliers").select("id,name,inn,contact_name,phone,email,comment,is_active,created_at").eq("company_id", companyId);
      if (search) q = q.ilike("name", ilike(search)); const { data, error } = await q.order("name").limit(limit); if (error) throw error;
      return { dataset, rows: data ?? [], row_count: (data ?? []).length, limit };
    }
    if (dataset === "objects") {
      let q: any = client.from("objects").select("id,name,address,comment,is_active,created_at").eq("company_id", companyId);
      if (search) q = q.ilike("name", ilike(search)); const { data, error } = await q.order("name").limit(limit); if (error) throw error;
      return { dataset, rows: data ?? [], row_count: (data ?? []).length, limit };
    }
    if (dataset === "milestones") {
      let q: any = client.from("project_milestones").select("id,object_name,title,location,target_date,status,notes,created_at").eq("company_id", companyId).is("deleted_at", null);
      if (objectName) q = q.eq("object_name", objectName); if (status) q = q.eq("status", status); if (search) q = q.ilike("title", ilike(search));
      if (monthRange) q = q.gte("target_date", monthRange.start).lt("target_date", monthRange.end);
      const { data, error } = await q.order("target_date").limit(limit); if (error) throw error;
      return { dataset, rows: data ?? [], row_count: (data ?? []).length, limit };
    }
    if (dataset === "legal_matters") {
      let q: any = client.from("legal_matters").select("id,matter_type,title,description,risk_level,status,due_at,object_id,required_actions,result,requires_manager_decision,manager_question,decision_status,decision_comment,created_at").eq("company_id", companyId);
      if (status) q = q.eq("status", status); if (search) q = q.ilike("title", ilike(search)); if (monthRange) q = q.gte("created_at", `${monthRange.start}T00:00:00Z`).lt("created_at", `${monthRange.end}T00:00:00Z`);
      const { data, error } = await q.order("created_at", { ascending: false }).limit(limit); if (error) throw error;
      const rows = data ?? []; const ids = [...new Set(rows.map((r: any) => String(r.object_id ?? "")).filter(Boolean))] as string[]; const objects = await objectMap(client, companyId, ids);
      let enriched = rows.map((r: any) => ({ ...r, object_name: objects[String(r.object_id ?? "")] ?? "" })); if (objectName) enriched = enriched.filter((r: any) => r.object_name === objectName);
      return { dataset, rows: enriched, row_count: enriched.length, limit };
    }
    if (dataset === "legal_documents") {
      let q: any = client.from("legal_documents").select("id,title,document_type,document_number,status,created_on,signed_on,valid_from,expires_on,object_id,comment,next_action,next_action_due_at,approval_status,created_at").eq("company_id", companyId).is("archived_at", null);
      if (status) q = q.eq("status", status); if (search) q = q.ilike("title", ilike(search)); if (monthRange) q = q.gte("created_at", `${monthRange.start}T00:00:00Z`).lt("created_at", `${monthRange.end}T00:00:00Z`);
      const { data, error } = await q.order("created_at", { ascending: false }).limit(limit); if (error) throw error;
      const rows = data ?? []; const ids = [...new Set(rows.map((r: any) => String(r.object_id ?? "")).filter(Boolean))] as string[]; const objects = await objectMap(client, companyId, ids);
      let enriched = rows.map((r: any) => ({ ...r, object_name: objects[String(r.object_id ?? "")] ?? "" })); if (objectName) enriched = enriched.filter((r: any) => r.object_name === objectName);
      return { dataset, rows: enriched, row_count: enriched.length, limit };
    }
    if (dataset === "recruitment_tasks") {
      let q: any = client.from("recruitment_crm_tasks").select("id,application_id,title,description,task_type,priority,due_at,status,assigned_to,created_at").eq("company_id", companyId);
      if (status) q = q.eq("status", status); if (search) q = q.ilike("title", ilike(search)); if (monthRange) q = q.gte("created_at", `${monthRange.start}T00:00:00Z`).lt("created_at", `${monthRange.end}T00:00:00Z`);
      const { data, error } = await q.order("due_at").limit(limit); if (error) throw error;
      const rows = data ?? []; const ids = [...new Set(rows.map((r: any) => String(r.application_id ?? "")).filter(Boolean))] as string[]; const candidates = await candidateMap(client, companyId, ids);
      const enriched = rows.map((r: any) => ({ ...r, candidate_name: candidates[String(r.application_id ?? "")]?.full_name ?? "" }));
      return { dataset, rows: enriched, row_count: enriched.length, limit };
    }
    if (dataset === "documents") {
      let q: any = client.from("employee_document_files").select("id,employee_id,document_type,file_kind,original_file_name,mime_type,quality_status,verification_status,created_at").eq("company_id", companyId);
      if (search) q = q.ilike("original_file_name", ilike(search)); if (monthRange) q = q.gte("created_at", `${monthRange.start}T00:00:00Z`).lt("created_at", `${monthRange.end}T00:00:00Z`);
      const { data, error } = await q.order("created_at", { ascending: false }).limit(limit); if (error) throw error;
      const rows = data ?? []; const ids = [...new Set(rows.map((r: any) => String(r.employee_id ?? "")).filter(Boolean))] as string[]; const employees = await employeeMap(client, companyId, ids);
      let enriched = rows.map((r: any) => ({ ...r, employee_name: employees[String(r.employee_id ?? "")]?.fio ?? "", object_name: employees[String(r.employee_id ?? "")]?.object_name ?? "" }));
      if (objectName) enriched = enriched.filter((r: any) => r.object_name === objectName); if (search) enriched = enriched.filter((r: any) => String(r.original_file_name ?? "").toLowerCase().includes(search.toLowerCase()) || String(r.employee_name).toLowerCase().includes(search.toLowerCase()));
      return { dataset, rows: enriched, row_count: enriched.length, limit };
    }
    return { dataset, error: "Набор данных не поддерживается" };
  } catch (error) {
    return { dataset, error: error instanceof Error ? error.message : String(error) };
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Метод не поддерживается" }, 405);
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const publishable = publishableKey();
    const secret = serviceKey();
    const authorization = request.headers.get("Authorization") ?? "";
    const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "";
    const model = Deno.env.get("OPENAI_MODEL")?.trim() || "gpt-5-mini";
    if (!supabaseUrl || !publishable || !secret || !authorization || !apiKey) return json({ error: "ChatGPT для AppСтрой не настроен" }, 500);

    const userClient: any = createClient(supabaseUrl, publishable, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } });
    const { data: authData, error: authError } = await userClient.auth.getUser();
    const user = authData.user;
    if (authError || !user) return json({ error: "Требуется повторный вход" }, 401);

    const input = await request.json().catch(() => ({})) as JsonMap;
    const companyId = clean(input.company_id, 80);
    const sourceMessageId = clean(input.source_message_id, 80);
    const objectName = clean(input.object_name, 180);
    if (!companyId || !sourceMessageId) return json({ error: "Не указано сообщение для ChatGPT" }, 400);

    const [{ data: canUseAi, error: aiPermissionError }, { data: canViewChat, error: chatPermissionError }] = await Promise.all([
      userClient.rpc("current_user_has_permission", { p_permission_code: "ai.use" }),
      userClient.rpc("current_user_has_permission", { p_permission_code: "company_chat.view" }),
    ]);
    if (aiPermissionError) throw aiPermissionError; if (chatPermissionError) throw chatPermissionError;
    if (canUseAi !== true) return json({ error: "Для этой роли ChatGPT отключён" }, 403);
    if (canViewChat !== true) return json({ error: "Нет доступа к чатам" }, 403);

    const admin: any = createClient(supabaseUrl, secret, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: membership, error: membershipError } = await admin.from("company_memberships").select("company_id,role,is_active").eq("company_id", companyId).eq("user_id", user.id).eq("is_active", true).maybeSingle();
    if (membershipError) throw membershipError; if (!membership) return json({ error: "Нет активного доступа к компании" }, 403);
    const role = clean(membership.role, 40);

    const { data: sourceData, error: sourceError } = await admin.from("company_chat_messages").select("id,company_id,sender_user_id,sender_name,kind,channel_kind,peer_user_id,thread_key,body,created_at,deleted_at,ai_payload").eq("company_id", companyId).eq("id", sourceMessageId).maybeSingle();
    if (sourceError) throw sourceError;
    const source = sourceData as ChatRow | null;
    if (!source || source.deleted_at || source.kind !== "user") return json({ error: "Исходное сообщение недоступно" }, 404);
    if (source.sender_user_id !== user.id) return json({ error: "ChatGPT может отвечать только на твой запрос" }, 403);
    if (source.channel_kind !== "assistant" || source.peer_user_id !== user.id) return json({ error: "Открой ChatGPT в разделе чата" }, 400);

    const { data: existing } = await admin.from("company_chat_messages").select("id").eq("company_id", companyId).eq("thread_key", source.thread_key).eq("kind", "assistant").eq("reply_to_id", sourceMessageId).is("deleted_at", null).maybeSingle();
    if (existing?.id) return json({ ok: true, message_id: existing.id, duplicate: true });

    const recentThreshold = new Date(Date.now() - 10_000).toISOString();
    const { count: recentCount, error: rateError } = await admin.from("company_chat_messages").select("id", { count: "exact", head: true }).eq("company_id", companyId).eq("thread_key", source.thread_key).eq("kind", "assistant").eq("ai_requester_user_id", user.id).gte("created_at", recentThreshold);
    if (rateError) throw rateError; if ((recentCount ?? 0) >= 2) return json({ error: "Подожди несколько секунд перед следующим сообщением" }, 429);

    const { data: recentData, error: recentError } = await admin.from("company_chat_messages").select("id,company_id,sender_user_id,sender_name,kind,channel_kind,peer_user_id,thread_key,body,created_at,deleted_at,ai_payload").eq("company_id", companyId).eq("thread_key", source.thread_key).gte("created_at", CHATGPT_CUTOVER).is("deleted_at", null).order("created_at", { ascending: false }).limit(24);
    if (recentError) throw recentError;
    const recent = ((recentData ?? []) as ChatRow[]).reverse();
    const context = conversationContext(recent, source);
    const history = recent.filter((item) => item.id !== source.id && item.body.trim()).slice(-16).map((item) => ({ role: item.kind === "assistant" ? "assistant" : "user", content: item.body.slice(0, 2200) }));

    const initialInput: unknown[] = [{
      role: "developer",
      content: [APP_KNOWLEDGE, `Сегодня по Москве: ${todayMsk()}.`, `Текущая роль: ${role || "не указана"}.`, objectName ? `Текущий объект: ${objectName}.` : "Конкретный объект сейчас не выбран.", Object.keys(context).length ? `Сохранённый контекст: ${JSON.stringify(context)}.` : ""].filter(Boolean).join("\n\n"),
    }, ...history, { role: "user", content: source.body.trim() ? source.body.slice(0, 4000) : "Пользователь отправил сообщение без текста." }];

    let transcript: unknown[] = [...initialInput];
    let responsePayload = await openAiResponse({ apiKey, model, input: transcript });
    const preparedActions: JsonMap[] = [];
    let latestAppResult: JsonMap = {};
    let latestAppStatus = 0;
    let mergedConversation: JsonMap = {};
    let semanticRoute: JsonMap = {};
    const toolTrace: JsonMap[] = [];

    for (let round = 0; round < MAX_TOOL_ROUNDS; round += 1) {
      const output = Array.isArray(responsePayload?.output) ? responsePayload.output : [];
      const calls = output.filter((item: any) => item?.type === "function_call" && ["appstroy_command", "appstroy_data", "appstroy_export"].includes(String(item?.name ?? ""))).slice(0, 6);
      if (!calls.length) break;
      transcript = [...transcript, ...output];
      const outputs: unknown[] = [];
      for (const call of calls) {
        const callId = String(call.call_id ?? "");
        if (call.name === "appstroy_export") {
          const action = parseExport(call, sourceMessageId); appendAction(preparedActions, action, sourceMessageId);
          toolTrace.push({ round: round + 1, tool: "export", action_type: clean(action.type) });
          outputs.push({ type: "function_call_output", call_id: callId, output: JSON.stringify({ ok: Object.keys(action).length > 0, action_prepared: Object.keys(action).length > 0, instruction: "Кнопка XLSX будет под финальным ответом." }) });
          continue;
        }
        if (call.name === "appstroy_data") {
          const dataResult = await queryData(userClient, companyId, parseArgs(call));
          toolTrace.push({ round: round + 1, tool: "data", dataset: clean(dataResult.dataset), row_count: Number(dataResult.row_count ?? 0), error: clean(dataResult.error, 240) });
          outputs.push({ type: "function_call_output", call_id: callId, output: JSON.stringify(dataResult) });
          continue;
        }
        const toolPrompt = parseToolPrompt(call, source.body);
        const appResult = await invokeAppStroy({ supabaseUrl, publishable, authorization, companyId, objectName, prompt: toolPrompt, context: { ...context, ...mergedConversation } });
        latestAppResult = appResult.data; latestAppStatus = appResult.status;
        const appAction = mapValue(appResult.data.action); appendAction(preparedActions, appAction, sourceMessageId);
        const conv = mapValue(appResult.data.conversation); if (Object.keys(conv).length) mergedConversation = { ...mergedConversation, ...conv };
        const route = mapValue(appResult.data.semantic_route); if (Object.keys(route).length) semanticRoute = route;
        toolTrace.push({ round: round + 1, tool: "command", status: appResult.status, action_type: clean(appAction.type), prompt: toolPrompt.slice(0, 300) });
        outputs.push({ type: "function_call_output", call_id: callId, output: JSON.stringify({ status: appResult.status, result: appResult.data }) });
      }
      transcript = [...transcript, ...outputs];
      responsePayload = await openAiResponse({ apiKey, model, input: transcript });
    }

    const action = finalAction(preparedActions, sourceMessageId);
    let answer = outputText(responsePayload);
    const actionType = clean(action.type, 100);
    const isExport = ["download_timesheet_excel", "download_payment_report", "download_appstroy_table"].includes(actionType) || (actionType === "voice_compound_batch" && preparedActions.some((a) => clean(a.type).startsWith("download_")));
    if (Object.keys(action).length && isExport && /(?:не могу|вручн|открой.*раздел|самостоятельно.*не)/i.test(answer)) {
      answer = preparedActions.length > 1 ? "Готово. Я подготовил план действий и нужную выгрузку — нажми кнопку ниже." : "Готово. Таблицу подготовил — нажми кнопку ниже, AppСтрой сформирует XLSX из актуальных данных.";
    }
    if (!answer && Object.keys(action).length) answer = preparedActions.length > 1 ? "Готово. Подготовил план действий — нажми кнопку ниже и проверь шаги." : "Готово. Действие подготовлено — нажми кнопку ниже.";
    if (!answer && Object.keys(latestAppResult).length) answer = clean(latestAppResult.summary, 6000) || clean(latestAppResult.error, 6000) || "AppСтрой вернул результат без текстового описания.";
    if (!answer) answer = "Не получилось сформировать ответ. Попробуй написать иначе.";
    if (Object.keys(action).length && !/(?:кнопк|подтверд|скача|действие.*готов)/i.test(answer)) answer = `${answer}\n\nДействие AppСтрой подготовлено — нажми кнопку ниже.`;

    const memory: JsonMap = {
      ...(mapValue(context)),
      ...(mergedConversation),
      object_name: clean(mergedConversation.object_name ?? context.object_name ?? objectName, 180) || null,
      month: clean(mergedConversation.month ?? context.month, 20) || null,
      last_action_types: preparedActions.map((a) => clean(a.type, 100)).filter(Boolean).slice(-8),
    };
    const storedPayload: JsonMap = {
      title: "ChatGPT", summary: answer, ai_used: true, assistant_mode: "chatgpt_app_agent_v2", model,
      app_tool_used: toolTrace.some((x) => x.tool === "command"), data_tool_used: toolTrace.some((x) => x.tool === "data"), export_tool_used: toolTrace.some((x) => x.tool === "export"),
      app_tool_status: latestAppStatus, unified_assistant: true, input_mode: "chatgpt", agent_steps: toolTrace.length, agent_memory: memory,
    };
    if (Object.keys(action).length) storedPayload.action = action;
    if (Object.keys(mergedConversation).length) storedPayload.conversation = mergedConversation;
    else { const c = mapValue(latestAppResult.conversation); if (Object.keys(c).length) storedPayload.conversation = c; }
    if (Object.keys(semanticRoute).length) storedPayload.semantic_route = semanticRoute;

    const { data: inserted, error: insertError } = await admin.from("company_chat_messages").insert({
      company_id: companyId, sender_user_id: null, sender_name: "ChatGPT", sender_role: "ai", kind: "assistant", channel_kind: "assistant", peer_user_id: user.id,
      thread_key: source.thread_key, body: answer.slice(0, 6000), reply_to_id: sourceMessageId, mentioned_user_ids: [user.id], ai_payload: storedPayload, ai_requester_user_id: user.id,
    }).select("id").single();
    if (insertError?.code === "23505") {
      const { data: duplicate } = await admin.from("company_chat_messages").select("id").eq("company_id", companyId).eq("thread_key", source.thread_key).eq("kind", "assistant").eq("reply_to_id", sourceMessageId).is("deleted_at", null).maybeSingle();
      return json({ ok: true, message_id: duplicate?.id ?? "", duplicate: true });
    }
    if (insertError) throw insertError;
    return json({ ok: true, message_id: inserted.id, assistant: "chatgpt", model, action_ready: Object.keys(action).length > 0, action_count: preparedActions.length, agent_steps: toolTrace.length });
  } catch (error) {
    console.error("company-chat-gpt agent v2 failed", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
