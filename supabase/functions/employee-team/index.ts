import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class HttpError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

type Viewer = {
  userId: string;
  role: string;
  companyId: string;
};

type SeedEmployee = {
  employeeId: string;
  personId: string;
  objectId: string;
  objectName: string;
};

const visibilityScopes = new Set([
  "private",
  "object",
  "company",
  "employers",
]);

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

function cleanText(value: unknown, maxLength: number) {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function cleanParagraph(value: unknown, maxLength: number) {
  return String(value ?? "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim()
    .slice(0, maxLength);
}

function cleanList(value: unknown, maxItems: number, maxItemLength: number) {
  if (!Array.isArray(value)) return [];
  const result: string[] = [];
  const seen = new Set<string>();
  for (const raw of value) {
    const item = cleanText(raw, maxItemLength);
    const key = item.toLocaleLowerCase("ru");
    if (!item || seen.has(key)) continue;
    seen.add(key);
    result.push(item);
    if (result.length >= maxItems) break;
  }
  return result;
}

function finiteNumber(value: unknown, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function visibilityScope(value: unknown) {
  const clean = cleanText(value, 20);
  return visibilityScopes.has(clean) ? clean : "object";
}

async function readBody(request: Request) {
  try {
    const raw = await request.json();
    return raw && typeof raw === "object"
      ? raw as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}

async function readViewer(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  userId: string,
): Promise<Viewer> {
  const { data, error } = await adminClient
    .from("user_profiles")
    .select("id, role, active_company_id, is_active")
    .eq("id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (error) throw error;
  if (!data?.active_company_id) {
    throw new HttpError("Компания пользователя не определена", 403);
  }
  if (!["employee", "admin", "developer"].includes(String(data.role))) {
    throw new HttpError("Команда объекта недоступна для этой роли", 403);
  }
  return {
    userId,
    role: String(data.role),
    companyId: String(data.active_company_id),
  };
}

async function seedForEmployee(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
): Promise<SeedEmployee> {
  const { data: link, error: linkError } = await adminClient
    .from("employee_account_links")
    .select("company_id, person_id, user_id")
    .eq("company_id", viewer.companyId)
    .eq("user_id", viewer.userId)
    .eq("is_active", true)
    .maybeSingle();
  if (linkError) throw linkError;
  if (!link?.person_id) {
    throw new HttpError("Связь с рабочей карточкой не найдена", 403);
  }

  const { data: employee, error: employeeError } = await adminClient
    .from("employees")
    .select("id, person_id, object_id, object_name, is_active, archived_at, updated_at")
    .eq("company_id", viewer.companyId)
    .eq("person_id", String(link.person_id))
    .eq("is_active", true)
    .is("archived_at", null)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (employeeError) throw employeeError;
  if (!employee?.id || !employee?.person_id) {
    throw new HttpError("Активная рабочая карточка не найдена", 404);
  }

  return {
    employeeId: String(employee.id),
    personId: String(employee.person_id),
    objectId: cleanText(employee.object_id, 80),
    objectName: cleanText(employee.object_name, 160),
  };
}

async function seedForManager(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  employeeId: string,
): Promise<SeedEmployee> {
  if (!employeeId) throw new HttpError("Сотрудник не выбран", 400);
  const { data: selected, error: selectedError } = await adminClient
    .from("employees")
    .select("id, person_id, object_id, object_name")
    .eq("id", employeeId)
    .eq("company_id", viewer.companyId)
    .maybeSingle();
  if (selectedError) throw selectedError;
  if (!selected?.person_id) {
    throw new HttpError("Единая карточка сотрудника не найдена", 404);
  }

  const { data: active, error: activeError } = await adminClient
    .from("employees")
    .select("id, person_id, object_id, object_name, is_active, archived_at, updated_at")
    .eq("company_id", viewer.companyId)
    .eq("person_id", String(selected.person_id))
    .eq("is_active", true)
    .is("archived_at", null)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (activeError) throw activeError;
  const employee = active ?? selected;

  return {
    employeeId: String(employee.id),
    personId: String(employee.person_id),
    objectId: cleanText(employee.object_id, 80),
    objectName: cleanText(employee.object_name, 160),
  };
}

async function currentVisibility(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  seed: SeedEmployee,
) {
  const { data, error } = await adminClient
    .from("employee_professional_profiles")
    .select("visibility_scope")
    .eq("company_id", viewer.companyId)
    .eq("person_id", seed.personId)
    .maybeSingle();
  if (error) throw error;
  return visibilityScope(data?.visibility_scope);
}

async function updateVisibility(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  seed: SeedEmployee,
  value: unknown,
) {
  if (viewer.role !== "employee") {
    throw new HttpError("Видимость меняет только сам сотрудник", 403);
  }
  const clean = cleanText(value, 20);
  if (!visibilityScopes.has(clean)) {
    throw new HttpError("Некорректный режим видимости", 400);
  }
  const { error } = await adminClient
    .from("employee_professional_profiles")
    .upsert(
      {
        company_id: viewer.companyId,
        person_id: seed.personId,
        user_id: viewer.userId,
        visibility_scope: clean,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "company_id,person_id" },
    );
  if (error) throw error;
  return clean;
}

async function teamMembers(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  seed: SeedEmployee,
) {
  if (!seed.objectId && !seed.objectName) {
    throw new HttpError("У сотрудника не указан текущий объект", 409);
  }

  let query = adminClient
    .from("employees")
    .select("id, person_id, fio, position, object_id, object_name, is_active, archived_at, updated_at")
    .eq("company_id", viewer.companyId)
    .eq("is_active", true)
    .is("archived_at", null);
  query = seed.objectId
    ? query.eq("object_id", seed.objectId)
    : query.eq("object_name", seed.objectName);

  const { data: rows, error: rowsError } = await query.order("updated_at", {
    ascending: false,
  });
  if (rowsError) throw rowsError;

  const byPerson = new Map<string, Record<string, unknown>>();
  for (const raw of rows ?? []) {
    const row = raw as Record<string, unknown>;
    const personId = cleanText(row.person_id, 80);
    if (!personId || personId === seed.personId || byPerson.has(personId)) continue;
    byPerson.set(personId, row);
  }
  const people = Array.from(byPerson.entries());
  const personIds = people.map(([personId]) => personId);
  if (personIds.length === 0) return [];

  const { data: profiles, error: profilesError } = await adminClient
    .from("employee_professional_profiles")
    .select("person_id, grade, experience_years, skills, about, ready_for_rotation, visibility_scope")
    .eq("company_id", viewer.companyId)
    .in("person_id", personIds);
  if (profilesError) throw profilesError;
  const profileMap = new Map<string, Record<string, unknown>>();
  for (const raw of profiles ?? []) {
    const row = raw as Record<string, unknown>;
    profileMap.set(cleanText(row.person_id, 80), row);
  }

  const summaries = await Promise.all(
    personIds.map(async (personId) => {
      const result = await adminClient.rpc("employee_professional_summary", {
        p_company_id: viewer.companyId,
        p_person_id: personId,
      });
      if (result.error) throw result.error;
      const summary = result.data && typeof result.data === "object"
        ? result.data as Record<string, unknown>
        : {};
      return [personId, summary] as const;
    }),
  );
  const summaryMap = new Map(summaries);
  const managerView = viewer.role === "admin" || viewer.role === "developer";

  return people
    .map(([personId, employee]) => {
      const profile = profileMap.get(personId) ?? {};
      const summary = summaryMap.get(personId) ?? {};
      const scope = visibilityScope(profile.visibility_scope);
      const extendedVisible = managerView || scope !== "private";
      return {
        employee_id: cleanText(employee.id, 80),
        full_name: cleanText(employee.fio, 180) || "Сотрудник",
        profession: cleanText(employee.position, 120),
        object_name: cleanText(employee.object_name, 160),
        total_shifts: finiteNumber(summary.total_shifts),
        completed_tasks: Math.max(
          0,
          Math.trunc(finiteNumber(summary.completed_tasks)),
        ),
        first_work_date: cleanText(summary.first_work_date, 20),
        extended_visible: extendedVisible,
        grade: extendedVisible ? cleanText(profile.grade, 40) : "",
        experience_years: extendedVisible
          ? finiteNumber(profile.experience_years)
          : 0,
        skills: extendedVisible ? cleanList(profile.skills, 20, 50) : [],
        about: extendedVisible ? cleanParagraph(profile.about, 800) : "",
        ready_for_rotation: extendedVisible &&
          profile.ready_for_rotation === true,
      };
    })
    .sort((a, b) => a.full_name.localeCompare(b.full_name, "ru"));
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
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new HttpError("Команда объекта не настроена", 500);
    }
    if (!authorization) throw new HttpError("Требуется вход", 401);

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) throw new HttpError("Требуется повторный вход", 401);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const viewer = await readViewer(adminClient, user.id);
    const input = await readBody(request);
    const action = cleanText(input.action, 30) || "list";
    const selectedEmployeeId = cleanText(input.employee_id, 80);
    const seed = viewer.role === "employee"
      ? await seedForEmployee(adminClient, viewer)
      : await seedForManager(adminClient, viewer, selectedEmployeeId);

    if (action === "update_visibility") {
      const next = await updateVisibility(
        adminClient,
        viewer,
        seed,
        input.visibility_scope,
      );
      return json({ ok: true, visibility_scope: next });
    }
    if (action !== "list") {
      throw new HttpError("Неизвестное действие", 400);
    }

    const [members, ownVisibility] = await Promise.all([
      teamMembers(adminClient, viewer, seed),
      viewer.role === "employee"
        ? currentVisibility(adminClient, viewer, seed)
        : Promise.resolve("private"),
    ]);

    return json({
      ok: true,
      current_object: seed.objectName,
      members,
      can_manage_visibility: viewer.role === "employee",
      visibility_scope: ownVisibility,
    });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : String(error);
    console.error("Employee team failed", {
      status,
      reason: status >= 500 ? "server_error" : "request_rejected",
    });
    return json(
      { error: message || "Не удалось загрузить команду объекта" },
      status,
    );
  }
});
