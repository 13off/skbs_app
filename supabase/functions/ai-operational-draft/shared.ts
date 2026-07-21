export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export type JsonMap = Record<string, unknown>;
export type EmployeeRow = {
  id: string;
  fio: string;
  position: string;
  phone: string;
  object_name: string;
  daily_rate: number;
};
export type CandidateRow = {
  id: string;
  full_name: string;
  phone: string;
  citizenship: string;
  position_title: string;
  status: string;
  ready_date: string | null;
  consent_personal_data: boolean;
  object_id: string | null;
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

export function normalized(value: unknown): string {
  return clean(value)
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/[–—−]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
}

export function tokens(value: unknown): string[] {
  return normalized(value)
    .replace(/[^а-яa-z0-9-]+/g, " ")
    .split(" ")
    .filter((token) => token.length >= 4);
}

export function nameMatches(prompt: string, fullName: string): boolean {
  const promptTokens = new Set(tokens(prompt));
  return tokens(fullName).some((nameToken) => {
    for (const promptToken of promptTokens) {
      if (promptToken === nameToken) return true;
      if (
        Math.min(promptToken.length, nameToken.length) >= 5 &&
        (promptToken.startsWith(nameToken) || nameToken.startsWith(promptToken))
      ) return true;
    }
    return false;
  });
}

export function dateKey(
  year: number | string,
  month: number | string,
  day: number | string,
) {
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

export function baseDate(value: unknown): Date {
  const text = clean(value, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
    const parsed = new Date(`${text}T00:00:00.000Z`);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

export function requestedDate(prompt: string, base: Date): string {
  const value = normalized(prompt);
  const iso = value.match(/\b(20\d{2})-(\d{1,2})-(\d{1,2})\b/);
  if (iso) return dateKey(iso[1], iso[2], iso[3]);
  const ru = value.match(/\b(\d{1,2})[.\/](\d{1,2})(?:[.\/](20\d{2}))?\b/);
  if (ru) return dateKey(ru[3] ?? base.getUTCFullYear(), ru[2], ru[1]);
  const result = new Date(base.getTime());
  if (/послезавтра/.test(value)) result.setUTCDate(result.getUTCDate() + 2);
  else if (/завтра/.test(value)) result.setUTCDate(result.getUTCDate() + 1);
  return dateKey(result.getUTCFullYear(), result.getUTCMonth() + 1, result.getUTCDate());
}

export function requestedMonth(prompt: string, base: Date): string {
  const value = normalized(prompt);
  const yearMatch = value.match(/\b(20\d{2})\b/);
  const monthNames: Array<[RegExp, number]> = [
    [/январ/, 1], [/феврал/, 2], [/март/, 3], [/апрел/, 4], [/ма[йя]/, 5],
    [/июн/, 6], [/июл/, 7], [/август/, 8], [/сентябр/, 9], [/октябр/, 10],
    [/ноябр/, 11], [/декабр/, 12],
  ];
  let month = base.getUTCMonth() + 1;
  for (const [pattern, valueMonth] of monthNames) {
    if (pattern.test(value)) {
      month = valueMonth;
      break;
    }
  }
  const year = yearMatch ? Number(yearMatch[1]) : base.getUTCFullYear();
  return `${year}-${String(month).padStart(2, "0")}`;
}

export function requestedTime(prompt: string): string {
  const value = normalized(prompt);
  const match = value.match(/(?:в|на)\s*(\d{1,2})(?::(\d{2}))?\b/);
  if (!match) return "09:00";
  const hour = Math.max(0, Math.min(23, Number(match[1])));
  const minute = Math.max(0, Math.min(59, Number(match[2] ?? 0)));
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

export function moneyFromPrompt(prompt: string): number {
  const match = normalized(prompt).match(/(\d[\d\s]{2,})(?:\s*(?:руб|₽))?/);
  return match ? Number(match[1].replace(/\s/g, "")) : Number.NaN;
}

export function paymentType(prompt: string): string {
  const value = normalized(prompt);
  if (/штраф/.test(value)) return "fine";
  if (/зарплат|заработн/.test(value)) return "salary";
  return "advance";
}

export function kind(prompt: string): string {
  const value = normalized(prompt);
  if (/напомн|напоминан/.test(value)) return "create_reminder";
  if (/(?:пакет|комплект).*(?:документ).*(?:кандидат|соискател)/.test(value) ||
      /(?:подготов|собер|проверь).*(?:документ).*(?:кандидат|соискател)/.test(value)) return "prepare_candidate_documents";
  if (/(?:нет|отсутств|без|не прикреп).*(?:чек)/.test(value) ||
      /(?:найд|покаж|проверь|какие).*(?:чек).*(?:нет|отсутств|не прикреп|без)/.test(value)) return "find_missing_receipts";
  if (/(?:сформир|подготов|созда|сдел).*(?:акт).*(?:выполн|работ|задач)/.test(value)) return "prepare_work_act";
  if (/(?:открой|покаж|собер|сформир).*(?:месячн|за месяц|период).*(?:табел)/.test(value)) return "open_period_timesheet";
  if (/(?:добав|созда|оформ).*(?:сотрудник|работник|человек)/.test(value)) return "create_employee_draft";
  if (/(?:подготов|добав|созда|провед|внес).*(?:выплат|аванс|зарплат|штраф)/.test(value)) return "prepare_payment";
  if (/(?:исправ|измен|поправ|постав|отмет).*(?:табел|смен)/.test(value) ||
      /(?:табел|смен).*(?:исправ|измен|поправ|постав|отмет)/.test(value)) return "prepare_timesheet_correction";
  if (/(?:измен|обнов|постав).*(?:ставк|должност|телефон)/.test(value)) return "prepare_employee_update";
  return "unknown";
}

export function actionResponse({
  type, title, button, summary, highlights, warnings, payload, objectName, date,
}: {
  type: string; title: string; button: string; summary: string;
  highlights: string[]; warnings: string[]; payload: JsonMap;
  objectName: string; date: string;
}) {
  return {
    ok: true,
    mode: "action_draft",
    title,
    summary,
    highlights,
    warnings,
    next_steps: ["Проверь все значения и явно подтверди действие."],
    scope: { object_name: objectName || "Все доступные объекты", date },
    preliminary: true,
    ai_used: false,
    action: {
      id: crypto.randomUUID(), type, title, button_label: button,
      confirmation_required: true, payload,
    },
  };
}
