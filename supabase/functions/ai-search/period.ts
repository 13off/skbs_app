import { clean, dateRu, norm } from "./shared.ts";

export interface PeriodFilter {
  start?: string;
  end?: string;
  label: string;
  explicit: boolean;
  allTime: boolean;
}

const months = [
  { pattern: /\bянвар[а-я]*\b/, month: 1 },
  { pattern: /\bфеврал[а-я]*\b/, month: 2 },
  { pattern: /\bмарт[а-я]*\b/, month: 3 },
  { pattern: /\bапрел[а-я]*\b/, month: 4 },
  { pattern: /\bма(?:й|я|е|ем|ю)\b/, month: 5 },
  { pattern: /\bиюн[а-я]*\b/, month: 6 },
  { pattern: /\bиюл[а-я]*\b/, month: 7 },
  { pattern: /\bавгуст[а-я]*\b/, month: 8 },
  { pattern: /\bсентябр[а-я]*\b/, month: 9 },
  { pattern: /\bоктябр[а-я]*\b/, month: 10 },
  { pattern: /\bноябр[а-я]*\b/, month: 11 },
  { pattern: /\bдекабр[а-я]*\b/, month: 12 },
];

function utcDate(year: number, month: number, day: number) {
  return new Date(Date.UTC(year, month - 1, day));
}

function iso(value: Date) {
  return `${value.getUTCFullYear()}-${String(value.getUTCMonth() + 1).padStart(2, "0")}-${String(value.getUTCDate()).padStart(2, "0")}`;
}

export function parsePeriod(prompt: string, fallbackDate: string): PeriodFilter {
  const text = norm(prompt);
  const fallback = /^(\d{4})-(\d{2})-(\d{2})$/.exec(clean(fallbackDate, 10));
  const today = fallback
    ? utcDate(Number(fallback[1]), Number(fallback[2]), Number(fallback[3]))
    : new Date();

  if (/весь период|всю историю|за все время|за всё время|все даты/.test(text)) {
    return { label: "весь доступный период", explicit: true, allTime: true };
  }

  const isoMatch = /\b(20\d{2})-(\d{2})-(\d{2})\b/.exec(text);
  if (isoMatch) {
    const value = `${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}`;
    return { start: value, end: value, label: dateRu(value), explicit: true, allTime: false };
  }

  const ruMatch = /\b(\d{1,2})[.\/-](\d{1,2})[.\/-](20\d{2})\b/.exec(text);
  if (ruMatch) {
    const value = iso(utcDate(Number(ruMatch[3]), Number(ruMatch[2]), Number(ruMatch[1])));
    return { start: value, end: value, label: dateRu(value), explicit: true, allTime: false };
  }

  if (/вчера|вчерашн/.test(text)) {
    const value = iso(new Date(today.getTime() - 86400000));
    return { start: value, end: value, label: dateRu(value), explicit: true, allTime: false };
  }

  if (/сегодня|сегодняшн|за день/.test(text)) {
    const value = iso(today);
    return { start: value, end: value, label: dateRu(value), explicit: true, allTime: false };
  }

  let year = today.getUTCFullYear();
  const yearMatch = /\b(20\d{2})\b/.exec(text);
  if (yearMatch) year = Number(yearMatch[1]);

  let month = 0;
  for (const item of months) {
    if (item.pattern.test(text)) { month = item.month; break; }
  }
  if (/прошл(?:ый|ом) месяц/.test(text)) {
    const previous = utcDate(today.getUTCFullYear(), today.getUTCMonth(), 1);
    year = previous.getUTCFullYear();
    month = previous.getUTCMonth() + 1;
  }
  if (/этот месяц|текущ(?:ий|ем) месяц|с начала месяца/.test(text)) {
    month = today.getUTCMonth() + 1;
  }
  if (month > 0) {
    const start = iso(utcDate(year, month, 1));
    const end = iso(new Date(Date.UTC(year, month, 0)));
    return { start, end, label: `${dateRu(start)} — ${dateRu(end)}`, explicit: true, allTime: false };
  }
  if (yearMatch) {
    return { start: `${year}-01-01`, end: `${year}-12-31`, label: String(year), explicit: true, allTime: false };
  }
  return { label: "без ограничения периода", explicit: false, allTime: false };
}

export function applyPeriod(query: any, column: string, period: PeriodFilter) {
  let result = query;
  if (period.start) result = result.gte(column, period.start);
  if (period.end) result = result.lte(column, period.end);
  return result;
}
