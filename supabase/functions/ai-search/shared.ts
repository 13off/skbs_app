export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const stopRoots = [
  /^покаж/, /^найд/, /^поиск/, /^вывед/, /^расскаж/, /^нужн/, /^хочу/,
  /^данн/, /^информац/, /^приложен/, /^бот/, /^помощник/, /^табел/,
  /^задач/, /^объект/, /^сотрудник/, /^работник/, /^выплат/, /^платеж/,
  /^чек/, /^квитанц/, /^компан/, /^приглаш/, /^пользовател/, /^документ/,
  /^сводк/, /^комментар/, /^заметк/, /^ося/, /^тариф/, /^лимит/,
  /^подписк/, /^биллинг/, /^невыполн/, /^выполнен/, /^просроч/,
  /^активн/, /^архивн/, /^уволен/, /^работа(?:ет|ют|л|ли|ла)$/,
  /^наход/, /^весь$/, /^все$/, /^всю$/, /^всех$/, /^какие$/, /^какой$/,
  /^кто$/, /^что$/, /^где$/, /^сколько$/, /^когда$/, /^за$/, /^на$/,
  /^по$/, /^для$/, /^про$/, /^из$/, /^от$/, /^до$/, /^или$/, /^это$/,
];

const monthPatterns = [
  /\bянвар[а-я]*\b/, /\bфеврал[а-я]*\b/, /\bмарт[а-я]*\b/,
  /\bапрел[а-я]*\b/, /\bма(?:й|я|е|ем|ю)\b/, /\bиюн[а-я]*\b/,
  /\bиюл[а-я]*\b/, /\bавгуст[а-я]*\b/, /\bсентябр[а-я]*\b/,
  /\bоктябр[а-я]*\b/, /\bноябр[а-я]*\b/, /\bдекабр[а-я]*\b/,
];

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

export function clean(value: unknown, max = 4000) {
  return String(value ?? "").trim().slice(0, max);
}

export function num(value: unknown) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function norm(value: unknown) {
  return clean(value).toLowerCase().replace(/ё/g, "е").replace(/[^а-яa-z0-9@._+-]+/g, " ").replace(/\s+/g, " ").trim();
}

export function rawTokens(value: unknown) {
  return norm(value).split(" ").filter((token) => token.length >= 3);
}

export function queryTokens(value: unknown) {
  return rawTokens(value).filter((token) => {
    if (/^\d{1,4}$/.test(token)) return false;
    if (monthPatterns.some((pattern) => pattern.test(token))) return false;
    return !stopRoots.some((pattern) => pattern.test(token));
  });
}

function tokenMatch(a: string, b: string) {
  if (a === b) return true;
  const size = Math.min(a.length, b.length);
  return size >= 4 && (a.startsWith(b) || b.startsWith(a) || (size >= 5 && b.includes(a)));
}

function score(tokens: string[], values: unknown[]) {
  if (tokens.length === 0) return 1;
  const candidates = rawTokens(values.map((value) => clean(value)).join(" "));
  let result = 0;
  for (const token of tokens) {
    const candidate = candidates.find((item) => tokenMatch(token, item));
    if (!candidate) return 0;
    result += token === candidate ? 5 : 3;
  }
  return result;
}

export function ranked<T>(rows: T[], tokens: string[], values: (row: T) => unknown[], limit = 20) {
  return rows.map((row) => ({ row, score: score(tokens, values(row)) }))
    .filter((item) => item.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((item) => item.row);
}

export function bestMatches<T>(rows: T[], prompt: string, values: (row: T) => unknown[]) {
  const tokens = rawTokens(prompt);
  const scored = rows.map((row) => {
    const candidates = rawTokens(values(row).map((value) => clean(value)).join(" "));
    let total = 0;
    for (const token of tokens) {
      const candidate = candidates.find((item) => tokenMatch(token, item));
      if (candidate) total += token === candidate ? 5 : 3;
    }
    return { row, total };
  }).filter((item) => item.total > 0).sort((a, b) => b.total - a.total);
  if (scored.length === 0) return [];
  return scored.filter((item) => item.total === scored[0].total).map((item) => item.row);
}

export function findEmployees(prompt: string, employees: any[]) {
  const tokens = rawTokens(prompt);
  const scored = employees.map((employee) => {
    const names = rawTokens(employee?.fio);
    let total = 0;
    names.forEach((name: string, index: number) => {
      for (const token of tokens) if (tokenMatch(token, name)) total += index === 0 ? 8 : 5;
    });
    return { employee, total };
  }).filter((item) => item.total > 0).sort((a, b) => b.total - a.total);
  if (scored.length === 0) return [];
  return scored.filter((item) => item.total === scored[0].total).map((item) => item.employee);
}

export function dateRu(value: unknown) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(clean(value, 10));
  return match ? `${match[3]}.${match[2]}.${match[1]}` : clean(value, 20);
}

export function dateTimeRu(value: unknown) {
  const date = new Date(clean(value, 40));
  if (Number.isNaN(date.getTime())) return clean(value, 40);
  return `${String(date.getUTCDate()).padStart(2, "0")}.${String(date.getUTCMonth() + 1).padStart(2, "0")}.${date.getUTCFullYear()}`;
}

export function money(value: unknown) {
  return `${Math.round(num(value)).toLocaleString("ru-RU")} ₽`;
}

export async function dataOrEmpty(query: any, label: string) {
  try {
    const { data, error } = await query;
    if (error) { console.warn(label, error.message ?? error); return []; }
    return data ?? [];
  } catch (error) {
    console.warn(label, error);
    return [];
  }
}

export function section(target: string[], title: string, lines: string[]) {
  if (lines.length > 0) target.push([title, ...lines].join("\n"));
}
