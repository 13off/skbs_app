export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export type EmployeeRow = {
  id: string;
  fio: string;
  object_name: string;
};

export type ObjectRow = {
  name: string;
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

export function clean(value: unknown, max = 4000): string {
  return String(value ?? "").trim().slice(0, max);
}

function normalizeConversationalCommand(value: string): string {
  return value
    // Вежливость и слова-паразиты не должны менять намерение команды.
    .replace(/\b(?:пожалуйста|плиз)\b/g, " ")
    .replace(/\b(?:ээ+|эмм+|ммм+|короче|слушай)\b/g, " ")
    // Навигация: пользователь говорит так, как привык в обычной речи.
    .replace(
      /\b(?:покажи|показать|выведи|вывести|отобрази|отобразить)\b/g,
      "открой",
    )
    .replace(/\b(?:зайди|зайти)\s+(?:в|на)\b/g, "открой ")
    .replace(/\bдавай\s+(?:в|на)\s+/g, "открой ")
    .replace(
      /\b(?:переключись|переключиться)\s+(?:на|в)\b/g,
      "перейди",
    )
    // Общие разговорные глаголы управления.
    .replace(/\b(?:поменяй|поменять|скорректируй|скорректировать)\b/g, "измени")
    .replace(/\b(?:заведи|завести)\b/g, "создай")
    .replace(/\b(?:закинь|закинуть)\s+задач\w*\b/g, "создай задачу")
    // Табель: короткие команды без слова «поставь» и рабочий жаргон.
    .replace(/\b(?:пол\s*дня|полдня)\b/g, "полсмены")
    .replace(
      /^(\s*)(всем|всех|каждому|все)(?=.*\b(?:единиц\w*|единичк\w*|ноль|нолик|полсмен|половин\w*|полтор\w*|два|две|три|[0-3](?:[.,]\d)?)\b)/,
      "$1поставь $2",
    )
    // Рабочий день сотрудника.
    .replace(/\b(?:стартуй|стартовать)\b/g, "начни")
    .replace(
      /\b(?:приступи|приступить)\s+к\s+(?:работе|смене|рабочему\s+дню)\b/g,
      "начни рабочий день",
    )
    .replace(/\b(?:начал|начала)\s+смену\b/g, "начни рабочий день")
    .replace(
      /\b(?:закончил|закончила|закончили|отработал|отработала)\s+(?:работу|смену|день)\b/g,
      "заверши рабочий день",
    )
    // Вылеты: живые формулировки и частые разговорные варианты.
    .replace(/\b(?:приземлился|приземлилась|сел\s+самолет)\b/g, "прилетел")
    .replace(/\b(?:улетел|улетела)\b/g, "вылетел")
    .replace(/\b(?:зарегался|зарегистрировался|зарегистрировалась)\b/g, "регистрация")
    // HR: разговорные переводы кандидатов между этапами.
    .replace(/\b(?:перекинь|перекинуть|передвинь|передвинуть)\b/g, "переведи")
    .replace(
      /\bотправь\s+(.+?)\s+на\s+билет(?:ы|ах)?\b/g,
      "переведи кандидата $1 на билеты",
    )
    // Сообщения: «скажи Гене, что…» превращается в безопасный черновик чата.
    .replace(/\bскажи\s+(.+?)\s*,?\s+что\s+/g, "напиши $1: ")
    .replace(/\b(?:черкни|напиши-ка)\b/g, "напиши")
    // Снабжение: естественное «закажи материал» = подготовить заявку.
    .replace(
      /\b(?:закажи|заказать)\s+(.+)$/g,
      "создай заявку на снабжение $1",
    )
    .replace(
      /\bнужно\s+заказать\s+(.+)$/g,
      "создай заявку на снабжение $1",
    )
    // Юрист: живые формулировки «вопрос юристам» / «задача юристам».
    .replace(
      /\bсоздай\s+(?:вопрос|задачу)\s+юрист(?:у|ам)?\s*[:\-]?\s*/g,
      "создай юридический вопрос ",
    )
    .replace(
      /\bпоставь\s+юрист(?:у|ам)?\s+(?:вопрос|задачу)\s*[:\-]?\s*/g,
      "создай юридический вопрос ",
    )
    // Решения и снабжение.
    .replace(/\b(?:подтверди|подтвердить|утверди|утвердить)\b/g, "согласуй")
    .replace(
      /\b(?:прими|принять)\s+(?:поставку|доставку)\b/g,
      "отметь доставку как доставлено",
    )
    // Архив: разговорные варианты восстановления.
    .replace(
      /\b(?:верни|вернуть|достань|достать)\s+(сотрудника|работника)\s+из\s+архива\b/g,
      "восстанови $1 из архива",
    )
    .replace(/\bразархивируй\s+(сотрудника|работника)\b/g, "восстанови $1 из архива")
    .replace(/\s+/g, " ")
    .trim();
}

export function normalized(value: unknown): string {
  const basic = clean(value)
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/[–—−]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
  return normalizeConversationalCommand(basic);
}

export function tokens(value: unknown): string[] {
  return normalized(value)
    .replace(/[^а-яa-z0-9.,-]+/g, " ")
    .split(" ")
    .filter(Boolean);
}

export function dateKey(year: number, month: number, day: number) {
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

export function baseDate(value: unknown): Date {
  const text = clean(value, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
    const parsed = new Date(`${text}T00:00:00.000Z`);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  const now = new Date();
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
}

export function requestedDate(prompt: string, base: Date): string {
  const value = normalized(prompt);
  const iso = value.match(/\b(20\d{2})-(\d{1,2})-(\d{1,2})\b/);
  if (iso) return dateKey(Number(iso[1]), Number(iso[2]), Number(iso[3]));
  const ru = value.match(/\b(\d{1,2})[./](\d{1,2})(?:[./](20\d{2}))?\b/);
  if (ru) {
    return dateKey(
      Number(ru[3] ?? base.getUTCFullYear()),
      Number(ru[2]),
      Number(ru[1]),
    );
  }
  const result = new Date(base.getTime());
  if (/послезавтра/.test(value)) result.setUTCDate(result.getUTCDate() + 2);
  else if (/завтра/.test(value)) result.setUTCDate(result.getUTCDate() + 1);
  else if (/вчера/.test(value)) result.setUTCDate(result.getUTCDate() - 1);
  return dateKey(
    result.getUTCFullYear(),
    result.getUTCMonth() + 1,
    result.getUTCDate(),
  );
}

export function nameTokens(fullName: string): string[] {
  return tokens(fullName).filter((token) => token.length >= 3);
}

function russianNameStem(token: string): string {
  if (!/^[а-я]+$/.test(token) || token.length < 4) return token;
  const suffixes = [
    "иями",
    "ями",
    "ами",
    "ого",
    "ему",
    "ому",
    "ией",
    "ей",
    "ой",
    "ам",
    "ям",
    "ах",
    "ях",
    "ы",
    "и",
    "е",
    "у",
    "ю",
    "а",
    "я",
  ];
  for (const suffix of suffixes) {
    if (!token.endsWith(suffix)) continue;
    const stem = token.slice(0, -suffix.length);
    if (stem.length >= 3) return stem;
  }
  return token;
}

function nameTokenMatches(left: string, right: string): boolean {
  if (left === right) return true;
  if (
    Math.min(left.length, right.length) >= 5 &&
    (left.startsWith(right) || right.startsWith(left))
  ) return true;

  const leftStem = russianNameStem(left);
  const rightStem = russianNameStem(right);
  return leftStem.length >= 3 &&
    rightStem.length >= 3 &&
    leftStem === rightStem;
}

export function nameMatches(prompt: string, fullName: string): boolean {
  const promptTokens = new Set(tokens(prompt));
  return nameTokens(fullName).some((nameToken) => {
    for (const promptToken of promptTokens) {
      if (nameTokenMatches(promptToken, nameToken)) return true;
    }
    return false;
  });
}

export function resultWithAction({
  title,
  summary,
  highlights = [],
  warnings = [],
  objectName = "",
  date,
  action,
}: {
  title: string;
  summary: string;
  highlights?: string[];
  warnings?: string[];
  objectName?: string;
  date: string;
  action: Record<string, unknown>;
}) {
  return {
    ok: true,
    mode: "global_voice",
    title,
    summary,
    highlights,
    warnings,
    next_steps: [],
    scope: {
      object_name: objectName || "Все доступные объекты",
      date,
    },
    preliminary: true,
    ai_used: false,
    action,
  };
}
