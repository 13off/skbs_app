import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";

const APP_KNOWLEDGE = [
  "Карта AppСтрой для единого ИИ-помощника:",
  "роли — руководитель/администратор, разработчик, прораб, бухгалтер, HR, юрист, снабженец, сотрудник; всегда соблюдай роль и доступный объект.",
  "руководитель — Главная, Люди/сотрудники, Отчёты, Задачи, Профиль; из рабочих экранов доступны Табель и Выплаты; есть выбор объекта.",
  "объекты и производство — объекты, сотрудники, задачи, виды работ, оси, исполнители, прогресс, вехи, цели и чек-листы.",
  "табель — смены, выходы, массовые и точечные исправления, отсутствие; изменение только через подтверждаемое действие.",
  "выплаты — начисления, авансы, выплаты, остатки, задолженность, штрафы, чеки и сверки с табелем.",
  "HR — кандидаты, этапы, ответственные, собеседования, оформление, пакет документов, архив, вылеты, прилёты, билеты и календарь рейсов.",
  "снабжение — заявки, позиции, материалы, количество, приоритет, поставщики, заказ, доставка и статусы.",
  "юридический блок — юридические вопросы, договоры, соглашения, претензии, риски, сроки, решения руководителя и обязательные действия.",
  "чат — общий чат компании, личные диалоги и отдельный письменный диалог с этим же ИИ-помощником.",
  "сотрудник — рабочий день, геолокация, свои задачи, начало/завершение работы и фото до/после.",
  "разработчик — диагностика, состояние системы, матрица ролей/прав и технические ограничения модулей.",
  "профиль/система — профиль, настройки, уведомления, роли и предпросмотр ролей.",
  "Голос и письменный чат — два интерфейса одного помощника. Сначала определи смысл команды, затем используй штатный модуль AppСтрой.",
  "Не выдумывай живые данные: ФИО, объект, смены, суммы, кандидатов, заявки, документы и статусы нужно брать из доступных данных приложения.",
  "Остаток/остатки выплат, задолженность сотрудникам и таблица остатков за месяц относятся к выплатам, а не к снабжению, если явно не сказано про материалы, склад, закупку или поставку.",
  "Никогда не считай изменение выполненным без штатной проверки и финального подтверждения пользователя.",
].join("\n");

function outputText(payload: any): string {
  if (typeof payload?.output_text === "string") return payload.output_text;
  const output = Array.isArray(payload?.output) ? payload.output : [];
  for (const item of output) {
    if (item?.type !== "message" || !Array.isArray(item?.content)) continue;
    for (const part of item.content) {
      if (part?.type === "output_text" && typeof part?.text === "string") {
        return part.text;
      }
    }
  }
  return "";
}

function normalize(value: unknown): string {
  return String(value ?? "")
    .toLowerCase()
    .replaceAll("ё", "е")
    .replace(/[–—−]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
}

function forcedSemanticResponse(
  messages: Array<{ role?: string; content?: unknown }>,
): string | null {
  const systemText = messages
    .filter((message) => message.role === "system" || message.role === "developer")
    .map((message) => String(message.content ?? ""))
    .join("\n");
  if (!systemText.includes("маршрутизатор голосового помощника AppСтрой")) {
    return null;
  }

  const userText = messages
    .filter((message) => message.role === "user")
    .map((message) => String(message.content ?? ""))
    .join("\n");
  const marker = userText.lastIndexOf("Фраза:");
  const phrase = normalize(marker >= 0 ? userText.slice(marker + 6) : userText);
  const payrollBalance = /(?:остатк|задолж|долг|недоплат|невыплат)/.test(phrase);
  const explicitProcurement =
    /(?:материал|склад|снабжен|закуп|поставк|заявк\s+снабжен|расходник)/.test(
      phrase,
    );
  if (!payrollBalance || explicitProcurement) return null;

  return JSON.stringify({
    intent: "operational_insight",
    subtype: "unpaid",
    confidence: 0.99,
    clarification: "",
  });
}

class OpenAISession {
  constructor(_requestedModel?: string) {}

  async run(
    input: { messages?: Array<{ role?: string; content?: unknown }> },
    options: { timeout?: number } = {},
  ) {
    const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "";
    if (!apiKey) throw new Error("OPENAI_API_KEY is not configured");

    const model = Deno.env.get("OPENAI_MODEL")?.trim() || "gpt-5-mini";
    const messages = Array.isArray(input?.messages) ? input.messages : [];
    const forced = forcedSemanticResponse(messages);
    if (forced != null) return { response: forced };

    const openAIInput = [
      { role: "developer", content: APP_KNOWLEDGE },
      ...messages.map((message) => ({
        role: message.role === "system" ? "developer" : (message.role || "user"),
        content: String(message.content ?? ""),
      })),
    ];

    const controller = new AbortController();
    const timeoutMs = Math.max(
      1000,
      Math.min(30000, Number(options.timeout ?? 8) * 1000),
    );
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ model, input: openAIInput }),
        signal: controller.signal,
      });

      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(
          payload?.error?.message || `OpenAI API error ${response.status}`,
        );
      }

      return { response: outputText(payload) };
    } finally {
      clearTimeout(timer);
    }
  }
}

function monthDateFromPrompt(prompt: string, fallbackDate: unknown): string | null {
  const value = normalize(prompt);
  const months: Array<[RegExp, number]> = [
    [/\bянвар[а-я]*\b/, 1],
    [/\bфеврал[а-я]*\b/, 2],
    [/\bмарт[а-я]*\b/, 3],
    [/\bапрел[а-я]*\b/, 4],
    [/\bма[йя][а-я]*\b/, 5],
    [/\bиюн[а-я]*\b/, 6],
    [/\bиюл[а-я]*\b/, 7],
    [/\bавгуст[а-я]*\b/, 8],
    [/\bсентябр[а-я]*\b/, 9],
    [/\bоктябр[а-я]*\b/, 10],
    [/\bноябр[а-я]*\b/, 11],
    [/\bдекабр[а-я]*\b/, 12],
  ];
  const match = months.find(([pattern]) => pattern.test(value));
  if (!match) return null;

  const baseText = String(fallbackDate ?? "");
  const baseMatch = /^(20\d{2})-(\d{2})-(\d{2})$/.exec(baseText);
  const now = new Date();
  const baseYear = baseMatch ? Number(baseMatch[1]) : now.getUTCFullYear();
  const baseMonth = baseMatch ? Number(baseMatch[2]) : now.getUTCMonth() + 1;
  const explicitYear = value.match(/\b(20\d{2})\b/);
  const month = match[1];
  let year = explicitYear ? Number(explicitYear[1]) : baseYear;
  if (!explicitYear && month > baseMonth) year -= 1;
  return `${year}-${String(month).padStart(2, "0")}-01`;
}

async function rewriteRequest(request: Request): Promise<Request> {
  if (request.method !== "POST") return request;
  const text = await request.text();
  let input: Record<string, unknown>;
  try {
    input = JSON.parse(text || "{}") as Record<string, unknown>;
  } catch (_) {
    return new Request(request.url, {
      method: request.method,
      headers: request.headers,
      body: text,
      signal: request.signal,
    });
  }

  const prompt = String(input.prompt ?? "").trim();
  const monthDate = monthDateFromPrompt(prompt, input.date);
  if (monthDate && !/\b20\d{2}-\d{2}-\d{2}\b/.test(prompt)) {
    input.prompt = `${prompt}\n\nПериод запроса: ${monthDate}`;
  }

  return new Request(request.url, {
    method: request.method,
    headers: request.headers,
    body: JSON.stringify(input),
    signal: request.signal,
  });
}

const runtime = (globalThis as unknown as { Supabase?: any }).Supabase;
if (runtime?.ai) {
  runtime.ai.Session = OpenAISession;
}

const originalEnvGet = Deno.env.get.bind(Deno.env);
(Deno.env as unknown as { get: (name: string) => string | undefined }).get = (
  name: string,
) => {
  if (name === "AI_INFERENCE_API_HOST") return "openai";
  if (name === "AI_SEMANTIC_MODE") return "openaicompatible";
  if (name === "AI_SEMANTIC_MODEL") {
    return originalEnvGet("OPENAI_MODEL")?.trim() || "gpt-5-mini";
  }
  return originalEnvGet(name);
};

const nativeServe = Deno.serve.bind(Deno);
(Deno as unknown as {
  serve: (
    handler: (request: Request) => Response | Promise<Response>,
  ) => unknown;
}).serve = (handler) =>
  nativeServe(async (request: Request) => handler(await rewriteRequest(request)));

await import(
  "https://raw.githubusercontent.com/13off/skbs_app/eaa9bfa41856bd4aea102578c4b6b82f59ca73fc/supabase/functions/ai-global-command/index.ts"
);
