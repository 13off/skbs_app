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
  is_active: boolean;
  archived_at: string | null;
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
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

function parseRequestedDate(prompt: string, baseDate: Date): string {
  const normalized = normalize(prompt);
  const isoMatch = normalized.match(/\b(20\d{2})-(\d{1,2})-(\d{1,2})\b/);
  if (isoMatch) {
    return `${isoMatch[1]}-${isoMatch[2].padStart(2, "0")}-${isoMatch[3].padStart(2, "0")}`;
  }

  const ruMatch = normalized.match(/\b(\d{1,2})[.\/](\d{1,2})(?:[.\/](20\d{2}))?\b/);
  if (ruMatch) {
    const year = ruMatch[3] ?? String(baseDate.getUTCFullYear());
    return `${year}-${ruMatch[2].padStart(2, "0")}-${ruMatch[1].padStart(2, "0")}`;
  }

  const result = new Date(baseDate.getTime());
  if (/послезавтра/.test(normalized)) result.setUTCDate(result.getUTCDate() + 2);
  else if (/завтра/.test(normalized)) result.setUTCDate(result.getUTCDate() + 1);
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
  const nameTokens = tokens(employee.fio);
  return nameTokens.some((token) => {
    for (const promptToken of promptTokens) {
      if (promptToken === token) return true;
      if (
        Math.min(promptToken.length, token.length) >= 5 &&
        (promptToken.startsWith(token) || token.startsWith(promptToken))
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

function extractWork(prompt: string, matchedEmployees: EmployeeRow[]): string {
  let result = prompt
    .replace(/\b(?:сегодня|завтра|послезавтра)\b/gi, " ")
    .replace(/\b(?:создай|создать|добавь|добавить|поставь|поставить|назначь|назначить|сделай|сделать)\b/gi, " ")
    .replace(/\bзадач(?:у|и|а)?\b/gi, " ")
    .replace(/(?:по\s+)?ос(?:и|ям|ях)?\s*[:\-]?\s*[^,.;]+/gi, " ")
    .replace(/фото\s*[«\"]?(?:до|после)[»\"]?[^,.;]*/gi, " ")
    .replace(/\bобязательн(?:о|ые|ый|ая)?\b/gi, " ");

  for (const employee of matchedEmployees) {
    const names = employee.fio
      .trim()
      .split(/\s+/)
      .filter((part) => part.length >= 4)
      .sort((a, b) => b.length - a.length);
    for (const name of names) {
      result = result.replace(new RegExp(`\\b${escapeRegExp(name)}[а-я]*\\b`, "gi"), " ");
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

function documentKind(prompt: string): string {
  const value = normalize(prompt);
  if (/заявлен.*(?:работ|прием)/.test(value)) return "job_application";
  if (/заявлен.*(?:зарплат|зп|перечислен)/.test(value)) return "salary_transfer_application";
  if (/соглас.*(?:персональн|обработк)/.test(value)) return "personal_data_consent";
  if (/трудов.*договор/.test(value)) return "employment_contract";
  if (/служебн.*записк/.test(value)) return "service_memo";
  if (/акт/.test(value)) return "work_act";
  if (/табел/.test(value)) return "timesheet";
  if (/письм/.test(value)) return "letter";
  return "work_document";
}

function classify(prompt: string): string {
  const value = normalize(prompt);
  if (
    /(?:созда|добав|постав|назнач|сдел).*задач/.test(value) ||
    /(?:постав|назнач).*(?:работ|армирован|бетонир|монтаж|демонтаж)/.test(value)
  ) {
    return "create_task_draft";
  }
  if (/напомн|напоминан/.test(value)) return "create_reminder";
  if (/исправ|поправ|постав.*смен|измен.*табел/.test(value)) {
    return "prepare_timesheet_correction";
  }
  if (/измен|обнов.*(?:сотрудник|ставк|телефон|должност)/.test(value)) {
    return "prepare_employee_update";
  }
  if (
    /(?:подготов|состав|созда|сдел).*\b(?:документ|акт|заявлен|договор|записк|письм|табел)/.test(value)
  ) {
    return "prepare_document";
  }
  return "unknown";
}

function actionResult({
  type,
  title,
  buttonLabel,
  summary,
  highlights,
  warnings,
  nextSteps,
  scope,
  payload,
}: {
  type: string;
  title: string;
  buttonLabel: string;
  summary: string;
  highlights: string[];
  warnings: string[];
  nextSteps: string[];
  scope: JsonMap;
  payload: JsonMap;
}) {
  return {
    ok: true,
    mode: "action_draft",
    title,
    summary,
    highlights,
    warnings,
    next_steps: nextSteps,
    scope,
    preliminary: true,
    ai_used: false,
    action: {
      id: crypto.randomUUID(),
      type,
      title,
      button_label: buttonLabel,
      confirmation_required: true,
      payload,
    },
  };
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

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Требуется повторный вход" }, 401);

    const input = await request.json().catch(() => ({})) as JsonMap;
    const companyId = cleanText(input.company_id, 80);
    const requestedObjectName = cleanText(input.object_name, 180);
    const prompt = cleanText(input.prompt, 4000);
    const baseDate = parseBaseDate(input.date);
    if (!companyId || !prompt) return json({ error: "Недостаточно данных запроса" }, 400);

    const { data: profile, error: profileError } = await userClient
      .from("user_profiles")
      .select("id, role, object_name, active_company_id, is_active")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.is_active !== true) {
      return json({ error: "Профиль пользователя недоступен" }, 403);
    }
    if (cleanText(profile.active_company_id, 80) !== companyId) {
      return json({ error: "Помощник работает только с активной компанией" }, 403);
    }

    const { data: membership, error: membershipError } = await userClient
      .from("company_memberships")
      .select("role, is_active")
      .eq("company_id", companyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return json({ error: "Нет доступа к выбранной компании" }, 403);

    const profileRole = cleanText(profile.role, 30);
    const membershipRole = cleanText(membership.role, 30);
    const isAdmin = profileRole === "admin" || ["owner", "admin"].includes(membershipRole);
    const assignedObjectName = cleanText(profile.object_name, 180);
    let effectiveObjectName = isAdmin ? requestedObjectName : assignedObjectName;

    const { data: objectRows, error: objectError } = await userClient
      .from("objects")
      .select("id, name")
      .eq("company_id", companyId)
      .eq("is_active", true)
      .order("name");
    if (objectError) throw objectError;
    const objects = objectRows ?? [];

    if (!effectiveObjectName && isAdmin) {
      const normalizedPrompt = normalize(prompt);
      const matchedObjects = objects.filter((object: any) => {
        const name = normalize(object.name);
        return name.length >= 3 && normalizedPrompt.includes(name);
      });
      if (matchedObjects.length === 1) effectiveObjectName = cleanText(matchedObjects[0].name, 180);
    }

    if (!isAdmin && !effectiveObjectName) {
      return json({ error: "Прорабу не назначен объект" }, 403);
    }
    if (effectiveObjectName) {
      const allowedObject = objects.some(
        (object: any) => cleanText(object.name, 180) === effectiveObjectName,
      );
      if (!allowedObject) return json({ error: "Объект недоступен" }, 403);
    }

    let employeeQuery: any = userClient
      .from("employees")
      .select("id, fio, position, object_name, is_active, archived_at")
      .eq("company_id", companyId)
      .eq("is_active", true)
      .is("archived_at", null)
      .order("fio");
    if (effectiveObjectName) employeeQuery = employeeQuery.eq("object_name", effectiveObjectName);
    const { data: employeeRows, error: employeeError } = await employeeQuery;
    if (employeeError) throw employeeError;
    const employees = (employeeRows ?? []) as EmployeeRow[];
    const matchedEmployees = employees.filter((employee) => employeeMatches(prompt, employee));

    const type = classify(prompt);
    const requestedDate = parseRequestedDate(prompt, baseDate);
    const scope = {
      object_name: effectiveObjectName || "Все доступные объекты",
      date: requestedDate,
    };

    if (type === "create_task_draft") {
      if (!effectiveObjectName) {
        return json({
          ok: true,
          mode: "action_draft",
          title: "Нужно выбрать объект",
          summary: "Для создания задачи выбери конкретный объект на Главной или назови его в запросе.",
          highlights: [],
          warnings: ["Без объекта черновик задачи не открывается."],
          next_steps: ["Выбери объект и повтори запрос."],
          scope,
          preliminary: true,
          ai_used: false,
        });
      }

      const axes = extractAxes(prompt);
      const work = extractWork(prompt, matchedEmployees);
      const beforePhotoRequested = /фото\s*[«\"]?до[»\"]?.*обяз|обяз.*фото\s*[«\"]?до/i.test(prompt);
      return json(actionResult({
        type,
        title: "Черновик задачи подготовлен",
        buttonLabel: "Открыть черновик задачи",
        summary: `${work}. Дата: ${requestedDate}. Объект: ${effectiveObjectName}.`,
        highlights: [
          `Вид работ: ${work}`,
          axes ? `Оси: ${axes}` : "Оси нужно проверить вручную",
          matchedEmployees.length > 0
            ? `Исполнители: ${matchedEmployees.map((employee) => employee.fio).join(", ")}`
            : "Исполнители не сопоставлены",
        ],
        warnings: [
          "ИИ ничего не сохраняет автоматически: проверь поля в обычной форме задачи.",
          ...(beforePhotoRequested ? ["Перед сохранением потребуется добавить фото «До»."] : []),
        ],
        nextSteps: ["Открой черновик, проверь данные и нажми «Сохранить задачу»."],
        scope,
        payload: {
          object_name: effectiveObjectName,
          date: requestedDate,
          axes,
          work,
          assignee_ids: matchedEmployees.map((employee) => employee.id),
          assignee_names: matchedEmployees.map((employee) => employee.fio),
          require_before_photo: beforePhotoRequested,
          source_prompt: prompt,
        },
      }));
    }

    if (type === "prepare_document") {
      const kind = documentKind(prompt);
      return json(actionResult({
        type,
        title: "Черновик документа подготовлен",
        buttonLabel: "Открыть документ",
        summary: "Определён тип документа и рабочий контекст. Содержимое нужно проверить перед скачиванием.",
        highlights: [
          `Тип: ${kind}`,
          matchedEmployees.length === 1
            ? `Сотрудник: ${matchedEmployees[0].fio}`
            : matchedEmployees.length > 1
            ? "Найдено несколько сотрудников"
            : "Сотрудник не указан",
        ],
        warnings: ["Юридически значимые данные и подписи требуют проверки человеком."],
        nextSteps: ["Открой предпросмотр, проверь текст и скачай документ."],
        scope,
        payload: {
          document_kind: kind,
          object_name: effectiveObjectName,
          date: requestedDate,
          employee_id: matchedEmployees.length === 1 ? matchedEmployees[0].id : "",
          employee_name: matchedEmployees.length === 1 ? matchedEmployees[0].fio : "",
          prompt,
        },
      }));
    }

    if (type === "prepare_timesheet_correction") {
      const shiftMatch = normalize(prompt).match(/(\d+(?:[.,]\d+)?)\s*(?:смен|смены)/);
      return json(actionResult({
        type,
        title: "Корректировка табеля подготовлена",
        buttonLabel: "Проверить корректировку",
        summary: "Изменение пока не применено и потребует отдельного подтверждения.",
        highlights: [
          matchedEmployees.length === 1 ? `Сотрудник: ${matchedEmployees[0].fio}` : "Уточни сотрудника",
          `Дата: ${requestedDate}`,
          shiftMatch ? `Смены: ${shiftMatch[1].replace(",", ".")}` : "Количество смен не найдено",
        ],
        warnings: ["До подтверждения табель не изменяется."],
        nextSteps: ["Проверь сотрудника, дату и количество смен."],
        scope,
        payload: {
          employee_id: matchedEmployees.length === 1 ? matchedEmployees[0].id : "",
          employee_name: matchedEmployees.length === 1 ? matchedEmployees[0].fio : "",
          object_name: effectiveObjectName,
          date: requestedDate,
          shifts: shiftMatch ? Number(shiftMatch[1].replace(",", ".")) : null,
          prompt,
        },
      }));
    }

    if (type === "prepare_employee_update") {
      const rateMatch = normalize(prompt).match(/(?:ставк[^\d]*)(\d[\d\s]{2,})/);
      return json(actionResult({
        type,
        title: "Изменение сотрудника подготовлено",
        buttonLabel: "Проверить изменение",
        summary: "Карточка сотрудника не изменена. Перед применением будут показаны старые и новые значения.",
        highlights: [
          matchedEmployees.length === 1 ? `Сотрудник: ${matchedEmployees[0].fio}` : "Уточни сотрудника",
          rateMatch ? `Новая ставка: ${rateMatch[1].replace(/\s/g, "")}` : "Изменяемое поле нужно уточнить",
        ],
        warnings: ["Изменение потребует явного подтверждения администратора."],
        nextSteps: ["Проверь сотрудника и новое значение."],
        scope,
        payload: {
          employee_id: matchedEmployees.length === 1 ? matchedEmployees[0].id : "",
          employee_name: matchedEmployees.length === 1 ? matchedEmployees[0].fio : "",
          object_name: effectiveObjectName,
          daily_rate: rateMatch ? Number(rateMatch[1].replace(/\s/g, "")) : null,
          prompt,
        },
      }));
    }

    if (type === "create_reminder") {
      return json(actionResult({
        type,
        title: "Напоминание подготовлено",
        buttonLabel: "Проверить напоминание",
        summary: "Текст напоминания подготовлен, но оно пока не создано.",
        highlights: [`Дата: ${requestedDate}`, `Текст: ${prompt}`],
        warnings: ["Получателей и точное время нужно проверить."],
        nextSteps: ["Открой настройки напоминания и подтверди создание."],
        scope,
        payload: {
          object_name: effectiveObjectName,
          date: requestedDate,
          title: "Рабочее напоминание",
          message: prompt,
        },
      }));
    }

    return json({
      ok: true,
      mode: "action_draft",
      title: "Не удалось определить действие",
      summary: "Сформулируй, что нужно подготовить: задачу, документ, корректировку табеля, изменение сотрудника или напоминание.",
      highlights: [],
      warnings: ["Данные приложения не изменялись."],
      next_steps: ["Например: «Поставь Иванову на завтра задачу армирование плиты по осям 1–5»."],
      scope,
      preliminary: true,
      ai_used: false,
    });
  } catch (error) {
    console.error("ai action draft failed", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
