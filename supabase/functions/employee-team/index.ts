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
    .select("id, person_id, fio, position, phone, object_id, object_name, is_active, archived_at, updated_at")
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

  const { data: links, error: linksError } = await adminClient
    .from("employee_account_links")
    .select("person_id, user_id, phone_e164")
    .eq("company_id", viewer.companyId)
    .eq("is_active", true)
    .in("person_id", personIds);
  if (linksError) throw linksError;

  const linkMap = new Map<string, Record<string, unknown>>();
  for (const raw of links ?? []) {
    const row = raw as Record<string, unknown>;
    const personId = cleanText(row.person_id, 80);
    if (personId && !linkMap.has(personId)) linkMap.set(personId, row);
  }

  const userIds = Array.from(
    new Set(
      Array.from(linkMap.values())
        .map((row) => cleanText(row.user_id, 80))
        .filter((value) => value.length > 0),
    ),
  );
  const profileMap = new Map<string, Record<string, unknown>>();
  if (userIds.length > 0) {
    const { data: profiles, error: profilesError } = await adminClient
      .from("user_profiles")
      .select("id, phone, avatar_path, is_active")
      .in("id", userIds)
      .eq("is_active", true);
    if (profilesError) throw profilesError;
    for (const raw of profiles ?? []) {
      const row = raw as Record<string, unknown>;
      profileMap.set(cleanText(row.id, 80), row);
    }
  }

  const avatarPaths = Array.from(
    new Set(
      Array.from(profileMap.values())
        .map((row) => cleanText(row.avatar_path, 500))
        .filter((value) => value.length > 0 && !value.startsWith("http")),
    ),
  );
  const avatarUrlMap = new Map<string, string>();
  if (avatarPaths.length > 0) {
    const { data: signed, error: signedError } = await adminClient.storage
      .from("profile-avatars")
      .createSignedUrls(avatarPaths, 60 * 60);
    if (!signedError) {
      for (const row of signed ?? []) {
        const path = cleanText(row.path, 500);
        const signedUrl = cleanText(row.signedUrl, 2000);
        if (path && signedUrl) avatarUrlMap.set(path, signedUrl);
      }
    }
  }

  return people
    .map(([personId, employee]) => {
      const link = linkMap.get(personId);
      const userId = cleanText(link?.user_id, 80);
      const profile = profileMap.get(userId);
      const avatarPath = cleanText(profile?.avatar_path, 500);
      const avatarUrl = avatarPath.startsWith("http")
        ? avatarPath
        : avatarUrlMap.get(avatarPath) ?? "";
      const phone = cleanText(employee.phone, 60) ||
        cleanText(link?.phone_e164, 60) ||
        cleanText(profile?.phone, 60);

      return {
        employee_id: cleanText(employee.id, 80),
        full_name: cleanText(employee.fio, 180) || "Сотрудник",
        profession: cleanText(employee.position, 120),
        phone,
        avatar_url: avatarUrl,
        profile_verified: Boolean(link && profile),
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
    if (action !== "list") {
      throw new HttpError("Неизвестное действие", 400);
    }

    const selectedEmployeeId = cleanText(input.employee_id, 80);
    const seed = viewer.role === "employee"
      ? await seedForEmployee(adminClient, viewer)
      : await seedForManager(adminClient, viewer, selectedEmployeeId);
    const members = await teamMembers(adminClient, viewer, seed);

    return json({
      ok: true,
      current_object: seed.objectName,
      members,
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
