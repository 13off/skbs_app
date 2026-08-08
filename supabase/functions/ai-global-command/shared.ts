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

export function nameMatches(prompt: string, fullName: string): boolean {
  const promptTokens = new Set(tokens(prompt));
  return nameTokens(fullName).some((nameToken) => {
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
