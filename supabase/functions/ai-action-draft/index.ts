import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonMap = Record<string, unknown>;
type EmployeeRow = {
  id: string;
  fio: string;
  position: string;
  object_name: string;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function cleanText(value: unknown, maxLength = 4000): string {
  return String(value ?? "").trim().slice(0, maxLength);
}

function normalize(value: unknown): string {
  return cleanText(value)
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/[–—−]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
}

function isoDate(value: Date): string {
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, "0");
  const day = String(value.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function parseBaseDate(value: unknown): Date {
  const candidate = cleanText(value, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(candidate)) {
    const parsed = new Date(`${candidate}T00:00:00.000Z`);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  const now = new Date();
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
}

function parseRequestedDate(prompt: string, baseDate: Date): string {
  const normalized = normalize(prompt);
  const isoMatch = normalized.match(/\b(20\d{2})-(\d{1,2})-(\d{1,2})\b/);
  if (isoMatch) {
    return `${isoMatch[1]}-${isoMatch[2].padStart(2, "0")}-$
      {isoMatch[3].padStart(2, "0")}`.replace(/\s+/g, "");
  }

  const ruMatch = normalized.match(
    /\b(\d{1,2})[.\/](\d{1,2})(?:[.\/](20\d{2}))?\b/,
  );
  if (ruMatch) {
    const year = ruMatch[3] ?? String(baseDate.getUTCFullYear());
    return `${year}-${ruMatch[2].padStart(2, "0")}-$
      {ruMatch[1].padStart(2, "0")}`.replace(/\s+/g, "");
  }

  const result = new Date(baseDate.getTime());
  if (/послезавтра/.test(normalized)) {
    result.setUTCDate(result.getUTCDate() + 2);
  } else if (/завтра/.test(normalized)) {
    result.setUTCDate(result.getUTCDate() + 1);
  }
  return isoDate(result);
}

function tokens(value: unknown): string[] {
  return normalize(value)
    .replace(/[^а-яa-z0-9-]+/g, " ")
    .split(" ")
    .filter((token) => token.length >= 4);
}

function employeeMatches(prompt: string, employee: EmployeeRow): boolean {
  const promptTokens = new Set(tokens(prompt));
  return tokens(employee.fio).some((nameToken) => {
    for (const promptToken of promptTokens) {
      if (promptToken === nameToken) return true;
      if (
        Math.min(promptToken.length, nameToken.length) >= 5 &&
        (promptToken.startsWith(nameToken) || nameToken.startsWith(promptToken))
      ) {
        return true;
      }
    }
    return false;
  });
}

function extractAxes(prompt: string): string {
  const match = prompt.match(
    /(?:по\s+)?ос(?:и|ям|ях)?\s*[:\-]?\s*([^,.;]+?)(?=\s+(?:фото|исполнител|сотрудник|обязатель)|[,.;]|$)/i,
  );
  return cleanText(match?.[1], 160);
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractWork(prompt: string, employees: EmployeeRow[]): string {
  let result = prompt
    .replace(/\b(?:сегодня|завтра|послезавтра)\b/gi, " ")
    .replace(
      /\b(?:создай|создать|добавь|добавить|поставь|поставить|назначь|назначить|сделай|сделать)\b/gi,
      " ",
    )
    .replace(/\bзадач(?:у|и|а)?\b/gi, " ")
    .replace(/(?:по\s+)?ос(?:и|ям|ях)?\s*[:\-]?\s*[^,.;]+/gi, " ")
    .replace(/фото\s*[«"]?(?:до|после)[»"]?[^,.;]*/gi, " ")
    .replace(/\bобязательн(?:о|ые|ый|ая)?\b/gi, " ");

  for (const employee of employees) {
    const nameParts = employee.fio
      .trim()
      .split(/\s+/)
      .filter((part) => part.length >= 4)
      .sort((a, b) => b.length - a.length);
    for (const part of nameParts) {
      result = result.replace(
        new RegExp(`\\b${escapeRegExp(part)}[а-я]*\\b`, "gi"),
        " ",
      );
    }
  }

  result = result
    .replace(/\b(?:на|для|и|к|по|в)\b/gi, " ")
    .replace(/[,:;.!?]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (result.length < 3) return "Уточнить вид работ";
  return result[0].toUpperCase() + result.slice(1);
}

function isTaskCommand(prompt: string): boolean {
  const value = normalize(prompt);
  return (
    /(?:созда|добав|постав|назнач|сдел).*задач/.test(value) ||
    /(?:постав|назнач).*(?:работ|армирован|бетонир|монтаж|демонтаж)/.test(
      value,
    )
  );
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Метод не поддерживается" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !authorization) {
      return json({ error: "Сервис действий ИИ не настроен" }, 500);
    }

    const client = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await client.auth.getUser();
    if (userError || !user) {
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const input = await request.json().catch(() => ({})) as JsonMap;
    const companyId = cleanText(input.company_id, 80);
    const requestedObjectName = cleanText(input.object_name, 180);
    const prompt = cleanText(input.prompt, 4000);
    const baseDate = parseBaseDate(input.date);
    if (!companyId || !prompt) {
      return json({ error: "Недостаточно данных запроса" }, 400);
    }
    if (!isTaskCommand(prompt)) {
      return json({ error: "Этот сервер готовит только черновики задач" }, 400);
    }

    const { data: profile, error: profileError } = await client
      .from("user_profiles")
      .select("role, object_name, active_company_id, is_active")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.is_active !== true) {
      return json({ error: "Профиль пользователя недоступен" }, 403);
    }
    if (cleanText(profile.active_company_id, 80) !== companyId) {
      return json({ error: "Помощник работает только с активной компанией" }, 403);
    }

    const { data: membership, error: membershipError } = await client
      .from("company_memberships")
      .select("role")
      .eq("company_id", companyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) {
      return json({ error: "Нет доступа к выбранной компании" }, 403);
    }

    const profileRole = cleanText(profile.role, 30);
    const membershipRole = cleanText(membership.role, 30);
    const isAdmin =
      profileRole === "admin" ||
      membershipRole === "owner" ||
      membershipRole === "admin";
    const assignedObjectName = cleanText(profile.object_name, 180);
    let objectName = isAdmin ? requestedObjectName : assignedObjectName;

    const { data: objectRows, error: objectError } = await client
      .from("objects")
      .select("name")
      .eq("company_id", companyId)
      .eq("is_active", true)
      .order("name");
    if (objectError) throw objectError;
    const objectNames = (objectRows ?? [])
      .map((row: any) => cleanText(row.name, 180))
      .filter((name: string) => name.length > 0);

    if (!objectName && isAdmin) {
      const normalizedPrompt = normalize(prompt);
      const matches = objectNames.filter((name: string) =>
        normalizedPrompt.includes(normalize(name))
      );
      if (matches.length === 1) objectName = matches[0];
    }
    if (!objectName) {
      return json({
        ok: true,
        title: "Нужно выбрать объект",
        summary:
          "Для создания задачи выбери конкретный объект на Главной или назови его в запросе.",
        highlights: [],
        warnings: ["Без объекта черновик задачи не открывается."],
        next_steps: ["Выбери объект и повтори запрос."],
        scope: { object_name: "Все доступные объекты", date: isoDate(baseDate) },
        preliminary: true,
        ai_used: false,
      });
    }
    if (!objectNames.includes(objectName)) {
      return json({ error: "Объект недоступен" }, 403);
    }

    const { data: employeeRows, error: employeeError } = await client
      .from("employees")
      .select("id, fio, position, object_name")
      .eq("company_id", companyId)
      .eq("object_name", objectName)
      .eq("is_active", true)
      .is("archived_at", null)
      .order("fio");
    if (employeeError) throw employeeError;
    const employees = (employeeRows ?? []) as EmployeeRow[];
    const matchedEmployees = employees.filter((employee) =>
      employeeMatches(prompt, employee)
    );

    const requestedDate = parseRequestedDate(prompt, baseDate);
    const axes = extractAxes(prompt);
    const work = extractWork(prompt, matchedEmployees);
    const requireBeforePhoto =
      /фото\s*[«"]?до[»"]?.*обяз|обяз.*фото\s*[«"]?до/i.test(prompt);

    return json({
      ok: true,
      mode: "action_draft",
      title: "Черновик задачи подготовлен",
      summary: `${work}. Дата: ${requestedDate}. Объект: ${objectName}.`,
      highlights: [
        `Вид работ: ${work}`,
        axes ? `Оси: ${axes}` : "Оси нужно проверить вручную",
        matchedEmployees.length > 0
          ? `Исполнители: ${matchedEmployees.map((item) => item.fio).join(", ")}`
          : "Исполнители не сопоставлены",
      ],
      warnings: [
        "ИИ ничего не сохраняет автоматически: проверь поля в обычной форме задачи.",
        ...(requireBeforePhoto
          ? ["Перед сохранением потребуется добавить фото «До»." ]
          : []),
      ],
      next_steps: [
        "Открой черновик, проверь данные и нажми «Сохранить задачу».",
      ],
      scope: { object_name: objectName, date: requestedDate },
      preliminary: true,
      ai_used: false,
      action: {
        id: crypto.randomUUID(),
        type: "create_task_draft",
        title: "Черновик задачи",
        button_label: "Открыть черновик задачи",
        confirmation_required: true,
        payload: {
          object_name: objectName,
          date: requestedDate,
          axes,
          work,
          assignee_ids: matchedEmployees.map((item) => item.id),
          assignee_names: matchedEmployees.map((item) => item.fio),
          require_before_photo: requireBeforePhoto,
          source_prompt: prompt,
        },
      },
    });
  } catch (error) {
    console.error("ai action draft failed", error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
