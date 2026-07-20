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

function dateKey(value: unknown): string {
  const clean = cleanText(value, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(clean)) return clean;
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}-${String(now.getUTCDate()).padStart(2, "0")}`;
}

function documentKind(prompt: string): string {
  const value = normalize(prompt);
  if (/заявлен.*(?:зарплат|зп|перечислен)/.test(value)) {
    return "salary_transfer_application";
  }
  if (/заявлен.*(?:работ|прием|принят)/.test(value)) {
    return "job_application";
  }
  if (/соглас.*(?:персональн|обработк)/.test(value)) {
    return "personal_data_consent";
  }
  if (/трудов.*договор/.test(value)) return "employment_contract";
  if (/служебн.*записк/.test(value)) return "service_memo";
  if (/акт/.test(value)) return "work_act";
  if (/письм/.test(value)) return "letter";
  return "work_document";
}

function documentTitle(kind: string): string {
  switch (kind) {
    case "job_application":
      return "Заявление о приёме на работу";
    case "salary_transfer_application":
      return "Заявление о перечислении заработной платы";
    case "personal_data_consent":
      return "Согласие на обработку персональных данных";
    case "employment_contract":
      return "Черновик трудового договора";
    case "service_memo":
      return "Служебная записка";
    case "work_act":
      return "Черновик акта";
    case "letter":
      return "Рабочее письмо";
    default:
      return "Рабочий документ";
  }
}

function requiresPrivateAccess(kind: string): boolean {
  return [
    "job_application",
    "salary_transfer_application",
    "personal_data_consent",
    "employment_contract",
  ].includes(kind);
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
      return json({ error: "Сервис документов не настроен" }, 500);
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
    const requestDate = dateKey(input.date);
    if (!companyId || !prompt) {
      return json({ error: "Недостаточно данных запроса" }, 400);
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

    const membershipRole = cleanText(membership.role, 30);
    const profileRole = cleanText(profile.role, 30);
    const canReadPrivate = ["owner", "admin", "developer", "hr"].includes(
      membershipRole,
    ) || ["admin", "developer", "hr"].includes(profileRole);
    const kind = documentKind(prompt);
    if (requiresPrivateAccess(kind) && !canReadPrivate) {
      return json(
        { error: "Кадровые документы доступны администратору или HR" },
        403,
      );
    }

    const assignedObjectName = cleanText(profile.object_name, 180);
    const isObjectRestricted = profileRole === "foreman" || membershipRole === "foreman";
    const objectName = isObjectRestricted
      ? assignedObjectName
      : requestedObjectName;
    if (isObjectRestricted && !objectName) {
      return json({ error: "Прорабу не назначен объект" }, 403);
    }

    let employeeQuery: any = client
      .from("employees")
      .select("id, fio, position, object_name")
      .eq("company_id", companyId)
      .is("archived_at", null)
      .order("fio");
    if (objectName) employeeQuery = employeeQuery.eq("object_name", objectName);
    const { data: employeeRows, error: employeeError } = await employeeQuery;
    if (employeeError) throw employeeError;
    const employees = (employeeRows ?? []) as EmployeeRow[];
    const matches = employees.filter((employee) =>
      employeeMatches(prompt, employee)
    );
    const employee = matches.length === 1 ? matches[0] : null;

    const title = documentTitle(kind);
    const warnings = [
      "Текст формируется как черновик и требует проверки человеком.",
      "Подписи и отправка документа автоматически не выполняются.",
    ];
    if (!employee && requiresPrivateAccess(kind)) {
      warnings.push("Сотрудник не сопоставлен однозначно — выбери его в предпросмотре.");
    }

    return json({
      ok: true,
      mode: "action_draft",
      title: `${title} подготовлен`,
      summary:
        "Тип документа и рабочий контекст определены. Персональные данные будут подставлены локально из доступной карточки сотрудника.",
      highlights: [
        `Документ: ${title}`,
        employee ? `Сотрудник: ${employee.fio}` : "Сотрудник не выбран",
        objectName ? `Объект: ${objectName}` : "Все доступные объекты",
      ],
      warnings,
      next_steps: [
        "Открой предпросмотр, проверь текст и скачай Word-файл.",
      ],
      scope: {
        object_name: objectName || "Все доступные объекты",
        date: requestDate,
      },
      preliminary: true,
      ai_used: false,
      action: {
        id: crypto.randomUUID(),
        type: "prepare_document",
        title,
        button_label: "Открыть документ",
        confirmation_required: true,
        payload: {
          document_kind: kind,
          title,
          company_id: companyId,
          object_name: objectName,
          date: requestDate,
          employee_id: employee?.id ?? "",
          employee_name: employee?.fio ?? "",
          source_prompt: prompt,
        },
      },
    });
  } catch (error) {
    console.error("ai document draft failed", error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
