import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export type SemanticIntent =
  | "query_employees"
  | "query_tasks"
  | "query_candidates"
  | "query_procurement"
  | "hr_stage_move"
  | "candidate_responsible"
  | "procurement_create"
  | "procurement_status"
  | "legal_create"
  | "legal_decision"
  | "timesheet_bulk"
  | "timesheet_update"
  | "task_create"
  | "document_draft"
  | "operational_insight"
  | "navigation"
  | "universal_search"
  | "fallback";

export type SemanticRoute = {
  intent: SemanticIntent;
  subtype: string;
  confidence: number;
  source: "local" | "llm";
  clarification: string;
};

export type SemanticConversationContext = {
  topic?: string;
  queryMode?: string;
  objectName?: string;
  previousPrompt?: string;
};

type CandidateRoute = SemanticRoute & { score: number };

const allowedIntents = new Set<SemanticIntent>([
  "query_employees",
  "query_tasks",
  "query_candidates",
  "query_procurement",
  "hr_stage_move",
  "candidate_responsible",
  "procurement_create",
  "procurement_status",
  "legal_create",
  "legal_decision",
  "timesheet_bulk",
  "timesheet_update",
  "task_create",
  "document_draft",
  "operational_insight",
  "navigation",
  "universal_search",
  "fallback",
]);

const writeIntents = new Set<SemanticIntent>([
  "hr_stage_move",
  "candidate_responsible",
  "procurement_create",
  "procurement_status",
  "legal_create",
  "legal_decision",
  "timesheet_bulk",
  "timesheet_update",
  "task_create",
]);

function normalize(value: unknown): string {
  return String(value ?? "")
    .toLowerCase()
    .replaceAll("ё", "е")
    .replace(/[^а-яa-z0-9.,:+\-\/ ]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function words(value: string): string[] {
  return normalize(value)
    .split(/\s+/)
    .map((item) => item.replace(/^[.,:+\-\/]+|[.,:+\-\/]+$/g, ""))
    .filter(Boolean);
}

function editDistance(first: string, second: string): number {
  const a = first.slice(0, 32);
  const b = second.slice(0, 32);
  const row = Array.from({ length: b.length + 1 }, (_, index) => index);
  for (let i = 1; i <= a.length; i += 1) {
    let diagonal = row[0];
    row[0] = i;
    for (let j = 1; j <= b.length; j += 1) {
      const old = row[j];
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      row[j] = Math.min(row[j] + 1, row[j - 1] + 1, diagonal + cost);
      diagonal = old;
    }
  }
  return row[b.length];
}

function tokenLike(token: string, root: string): boolean {
  if (token === root || token.startsWith(root) || root.startsWith(token)) return true;
  if (Math.min(token.length, root.length) < 5) return false;
  if (Math.abs(token.length - root.length) > 1) return false;
  return editDistance(token, root) <= 1;
}

function hasAny(value: string, roots: string[]): boolean {
  const sourceWords = words(value);
  return roots.some((root) => sourceWords.some((token) => tokenLike(token, root)));
}

function hasPhrase(value: string, patterns: RegExp[]): boolean {
  const text = normalize(value);
  return patterns.some((pattern) => pattern.test(text));
}

function add(
  routes: CandidateRoute[],
  intent: SemanticIntent,
  score: number,
  subtype = "",
) {
  routes.push({
    intent,
    subtype,
    score,
    confidence: Math.min(0.97, 0.5 + score / 10),
    source: "local",
    clarification: "",
  });
}

function navigationSubtype(value: string): string {
  const groups: Array<[string, string[]]> = [
    ["timesheet", ["табел", "смен", "выход"]],
    ["employees", ["сотрудник", "работник", "люди"]],
    ["tasks", ["задач", "наряд", "работ"]],
    ["payments", ["выплат", "деньги", "зарплат", "аванс"]],
    ["recruitment", ["кандидат", "подбор", "кадр", "воронка"]],
    ["procurement", ["снабжен", "закуп", "заявк"]],
    ["legal", ["юрист", "юрид", "претенз"]],
    ["objects", ["объект", "стройка", "площадка"]],
    ["chat", ["чат", "сообщен", "перепис"]],
    ["settings", ["настройк", "профил"]],
  ];
  for (const [target, roots] of groups) {
    if (hasAny(value, roots)) return target;
  }
  return "";
}

function localRoute(
  prompt: string,
  context: SemanticConversationContext,
): SemanticRoute {
  const value = normalize(prompt);
  const routes: CandidateRoute[] = [];
  const employee = hasAny(value, [
    "сотрудник",
    "работник",
    "человек",
    "бригада",
    "бетонщик",
    "арматурщик",
    "мастер",
    "прораб",
  ]);
  const candidate = hasAny(value, [
    "кандидат",
    "соискател",
    "анкета",
    "резюме",
    "кадр",
  ]) || context.topic === "candidates";
  const procurement = hasAny(value, [
    "снабжен",
    "закуп",
    "постав",
    "материал",
    "арматур",
    "бетон",
    "фанер",
    "крепеж",
    "расходник",
    "заказ",
  ]) || context.topic === "procurement";
  const legal = hasAny(value, [
    "юрист",
    "юрид",
    "претенз",
    "иск",
    "договор",
    "правов",
    "суд",
  ]);
  const timesheet = hasAny(value, [
    "табел",
    "смен",
    "выход",
    "явк",
    "невыход",
    "отработ",
    "присутств",
  ]);
  const task = hasAny(value, [
    "задач",
    "работ",
    "наряд",
    "армирован",
    "бетонир",
    "монтаж",
    "демонтаж",
    "залив",
  ]);
  const question = hasAny(value, [
    "кто",
    "что",
    "сколько",
    "какие",
    "где",
    "покажи",
    "перечисли",
    "найди",
    "глянь",
    "посмотри",
    "дай",
    "скин",
    "выдай",
    "таблиц",
  ]);
  const move = hasAny(value, [
    "перевед",
    "перемест",
    "перекин",
    "закин",
    "двин",
    "отправ",
    "постав",
  ]);
  const assign = hasAny(value, [
    "ответствен",
    "назнач",
    "закреп",
    "повесь",
    "прикреп",
    "поруч",
  ]);
  const create = hasAny(value, [
    "созда",
    "добав",
    "заведи",
    "сдел",
    "оформ",
    "подготов",
    "надо",
    "нужн",
  ]);
  const change = hasAny(value, [
    "измен",
    "исправ",
    "поправ",
    "постав",
    "отмет",
    "простав",
    "заполн",
  ]);
  const approve = hasAny(value, ["соглас", "одобр", "утверд", "разреш"]);
  const reject = hasAny(value, ["отклон", "откаж", "отмен", "запрет"]);
  const everyone = hasAny(value, ["всем", "всех", "каждому", "бригада", "целиком"]);
  const status = hasAny(value, [
    "статус",
    "этап",
    "дальше",
    "готов",
    "заказан",
    "достав",
    "привез",
    "получен",
  ]);

  if (candidate && move) add(routes, "hr_stage_move", 8.5);
  if (candidate && assign) add(routes, "candidate_responsible", 8.4);
  if (procurement && create && !status) add(routes, "procurement_create", 7.8);
  if (procurement && (move || status || approve || reject)) {
    let subtype = "";
    if (hasAny(value, ["доставлен", "привез", "получен"])) subtype = "delivered";
    else if (hasPhrase(value, [/в доставк/, /едет/, /в пути/])) subtype = "in_delivery";
    else if (hasAny(value, ["заказан", "заказали"])) subtype = "ordered";
    else if (reject || hasAny(value, ["аннулир"])) subtype = "canceled";
    else if (approve) subtype = "approved";
    add(routes, "procurement_status", 7.7, subtype);
  }
  if (legal && (approve || reject)) {
    add(routes, "legal_decision", 8.2, reject ? "reject" : "approve");
  } else if (legal && create) {
    add(routes, "legal_create", 7.6);
  }
  if (timesheet && everyone && change) add(routes, "timesheet_bulk", 8.1);
  else if (timesheet && change) add(routes, "timesheet_update", 7.7);

  const absent = hasPhrase(value, [
    /не\s*(?:выш|пришел|явил)/,
    /нет\s+на\s+работ/,
    /прогул/,
    /отсутств/,
  ]);
  const unpaid = hasAny(value, ["долг", "задолж", "недоплат", "невыплат", "остатк", "расчетн"]);
  const expiring = hasAny(value, ["истека", "заканч", "просроч"]);
  const weekly = hasPhrase(value, [/за неделю/, /недельн/, /семь дней/, /7 дней/]);
  if ((absent || unpaid || expiring || weekly) && question) {
    add(
      routes,
      "operational_insight",
      8.3,
      absent
        ? "absence"
        : unpaid
        ? "unpaid"
        : expiring
        ? "expiring_documents"
        : "weekly_report",
    );
  }

  if (question && employee) add(routes, "query_employees", 6.8);
  if (question && task) add(routes, "query_tasks", 6.8);
  if (question && candidate) add(routes, "query_candidates", 7.0);
  if (question && procurement) add(routes, "query_procurement", 7.0);
  if (task && create && !question) add(routes, "task_create", 6.9);

  const document = hasAny(value, [
    "документ",
    "заявлен",
    "письм",
    "служеб",
    "акт",
    "объяснител",
  ]);
  if (document && create && !candidate) add(routes, "document_draft", 6.9);

  const open = hasAny(value, ["открой", "зайди", "перейд", "кинь", "перекин", "веди"]);
  const navTarget = navigationSubtype(value);
  if (open && navTarget) add(routes, "navigation", 7.4, navTarget);

  const search = hasAny(value, ["найди", "поищи", "отыщи", "где", "покажи", "посмотри"]);
  if (search && routes.length === 0) add(routes, "universal_search", 5.8);

  routes.sort((first, second) => second.score - first.score);
  const best = routes[0];
  if (best == null) {
    return {
      intent: "fallback",
      subtype: "",
      confidence: 0,
      source: "local",
      clarification: "",
    };
  }
  const runnerUp = routes[1];
  if (runnerUp && Math.abs(best.score - runnerUp.score) < 0.35 && best.intent !== runnerUp.intent) {
    return {
      intent: "fallback",
      subtype: "",
      confidence: 0.45,
      source: "local",
      clarification: "",
    };
  }
  return best;
}

function extractJson(value: string): Record<string, unknown> | null {
  const clean = value.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  const first = clean.indexOf("{");
  const last = clean.lastIndexOf("}");
  if (first < 0 || last <= first) return null;
  try {
    const parsed = JSON.parse(clean.slice(first, last + 1));
    return parsed && typeof parsed === "object" ? parsed as Record<string, unknown> : null;
  } catch (_) {
    return null;
  }
}

function outputText(output: unknown): string {
  if (typeof output === "string") return output;
  if (!output || typeof output !== "object") return "";
  const map = output as Record<string, unknown>;
  if (typeof map.response === "string") return map.response;
  const message = map.message as Record<string, unknown> | undefined;
  if (typeof message?.content === "string") return message.content;
  const choices = map.choices;
  if (Array.isArray(choices) && choices.length > 0) {
    const first = choices[0] as Record<string, unknown>;
    const choiceMessage = first.message as Record<string, unknown> | undefined;
    if (typeof choiceMessage?.content === "string") return choiceMessage.content;
    if (typeof first.text === "string") return first.text;
  }
  return "";
}

async function llmRoute({
  prompt,
  role,
  context,
}: {
  prompt: string;
  role: string;
  context: SemanticConversationContext;
}): Promise<SemanticRoute | null> {
  if (!(Deno.env.get("AI_INFERENCE_API_HOST")?.trim())) return null;
  const runtime = (globalThis as unknown as { Supabase?: any }).Supabase;
  const Session = runtime?.ai?.Session;
  if (typeof Session !== "function") return null;
  const model = Deno.env.get("AI_SEMANTIC_MODEL")?.trim() || "mistral";
  const configuredMode = Deno.env.get("AI_SEMANTIC_MODE")?.trim().toLowerCase();
  const mode = configuredMode === "openaicompatible" ? "openaicompatible" : "ollama";
  const system = [
    "Ты маршрутизатор голосового помощника AppСтрой.",
    "Определи намерение по СМЫСЛУ, включая разговорную речь, жаргон, ошибки и непривычные формулировки.",
    "Не выполняй действие и не придумывай ФИО, объект, дату, количество, сумму, статус или материал.",
    "Верни только один intent из белого списка.",
    "Белый список: query_employees, query_tasks, query_candidates, query_procurement, hr_stage_move, candidate_responsible, procurement_create, procurement_status, legal_create, legal_decision, timesheet_bulk, timesheet_update, task_create, document_draft, operational_insight, navigation, universal_search, fallback.",
    "subtype только если очевидно: operational_insight=absence|unpaid|expiring_documents|weekly_report; legal_decision=approve|reject; procurement_status=approved|ordered|in_delivery|delivered|canceled; navigation=timesheet|employees|tasks|payments|recruitment|procurement|legal|objects|chat|settings.",
    "Фразы про остаток/остатки выплат, расчётный остаток, задолженность сотрудникам или таблицу остатков за месяц = operational_insight с subtype unpaid. Это НЕ снабжение, если явно не сказано про материалы, склад, закупку, поставку или заявку снабжения.",
    "JSON: {\"intent\":\"...\",\"subtype\":\"\",\"confidence\":0.0,\"clarification\":\"\"}",
  ].join("\n");
  const user = [
    `Роль: ${role}`,
    context.topic ? `Предыдущая тема: ${context.topic}` : "",
    context.queryMode ? `Предыдущий режим: ${context.queryMode}` : "",
    context.objectName ? `Текущий объект: ${context.objectName}` : "",
    context.previousPrompt ? `Предыдущая реплика: ${context.previousPrompt.slice(0, 500)}` : "",
    `Фраза: ${prompt}`,
  ].filter(Boolean).join("\n");

  try {
    const session = new Session(model);
    const output = await session.run(
      {
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
      },
      { mode, stream: false, timeout: 8 },
    );
    const parsed = extractJson(outputText(output));
    if (parsed == null) return null;
    const intent = String(parsed.intent ?? "") as SemanticIntent;
    if (!allowedIntents.has(intent)) return null;
    const rawConfidence = Number(parsed.confidence ?? 0);
    const confidence = Number.isFinite(rawConfidence)
      ? Math.max(0, Math.min(1, rawConfidence))
      : 0;
    const minimum = writeIntents.has(intent) ? 0.76 : 0.62;
    if (confidence < minimum) return null;
    return {
      intent,
      subtype: String(parsed.subtype ?? "").trim().slice(0, 80),
      confidence,
      source: "llm",
      clarification: String(parsed.clarification ?? "").trim().slice(0, 400),
    };
  } catch (error) {
    console.warn("semantic llm route unavailable", error);
    return null;
  }
}

export async function resolveSemanticVoiceIntent({
  prompt,
  role,
  context = {},
}: {
  prompt: string;
  role: string;
  context?: SemanticConversationContext;
}): Promise<SemanticRoute> {
  const local = localRoute(prompt, context);
  // Deterministic AppСтрой rules win whenever they already recognized the
  // request. OpenAI is a semantic fallback for genuinely unfamiliar wording,
  // not an override that can turn payroll balances into procurement.
  if (local.intent !== "fallback") return local;
  const llm = await llmRoute({ prompt, role, context });
  return llm ?? local;
}

export function semanticPrompt(route: SemanticRoute, originalPrompt: string): string {
  const hint = (() => {
    switch (route.intent) {
      case "query_employees": return "перечисли сотрудников";
      case "query_tasks": return "какие открытые задачи";
      case "query_candidates": return "какие кандидаты";
      case "query_procurement": return "какие заявки снабжения";
      case "hr_stage_move": return "переведи кандидата на этап";
      case "candidate_responsible": return "назначь ответственного кандидату";
      case "procurement_create": return "создай заявку на снабжение";
      case "procurement_status":
        if (route.subtype === "delivered") return "отметь заявку снабжения как доставлено";
        if (route.subtype === "in_delivery") return "переведи заявку снабжения в доставку";
        if (route.subtype === "ordered") return "отметь заявку снабжения как заказано";
        if (route.subtype === "approved") return "согласуй заявку снабжения";
        if (route.subtype === "canceled") return "отмени заявку снабжения";
        return "переведи заявку снабжения дальше";
      case "legal_create": return "создай юридическую задачу";
      case "legal_decision":
        return route.subtype === "reject"
          ? "отклони юридический вопрос"
          : "согласуй юридический вопрос";
      case "timesheet_bulk": return "массово поставь всем смены в табеле";
      case "timesheet_update": return "исправь табель и смены сотрудника";
      case "task_create": return "создай рабочую задачу";
      case "document_draft": return "подготовь рабочий документ";
      case "operational_insight":
        if (route.subtype === "absence") return "кто не вышел сегодня";
        if (route.subtype === "unpaid") return "кому не выплатили задолженность";
        if (route.subtype === "expiring_documents") return "у кого истекают документы";
        if (route.subtype === "weekly_report") return "сводка за неделю";
        return "операционная сводка";
      case "navigation": return `открой ${navigationHint(route.subtype)}`;
      case "universal_search": return "найди по данным приложения";
      case "fallback": return "";
    }
  })();
  return hint
    ? `${originalPrompt}\n\nСистемная семантическая подсказка: ${hint}.`
    : originalPrompt;
}

function navigationHint(subtype: string): string {
  const labels: Record<string, string> = {
    timesheet: "табель",
    employees: "сотрудники",
    tasks: "задачи",
    payments: "выплаты",
    recruitment: "кандидаты",
    procurement: "снабжение",
    legal: "юридический раздел",
    objects: "объекты",
    chat: "чат",
    settings: "настройки",
  };
  return labels[subtype] ?? (subtype || "главный раздел");
}
