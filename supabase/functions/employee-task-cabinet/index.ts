import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Row = Record<string, unknown>;

class HttpError extends Error {
  constructor(message: string, public status: number) {
    super(message);
  }
}

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

function text(value: unknown, maxLength = 500) {
  return String(value ?? "").trim().slice(0, maxLength);
}

function record(value: unknown): Row | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Row;
}

function records(value: unknown): Row[] {
  if (!Array.isArray(value)) return [];
  return value.map(record).filter((item): item is Row => item !== null);
}

async function bodyOf(request: Request): Promise<Row> {
  try {
    return record(await request.json()) ?? {};
  } catch {
    return {};
  }
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
    if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
      throw new HttpError("Кабинет сотрудника не настроен", 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) throw new HttpError("Требуется повторный вход", 401);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const input = await bodyOf(request);

    const { data: profileData, error: profileError } = await admin
      .from("user_profiles")
      .select("role, active_company_id, is_active")
      .eq("id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (profileError) throw profileError;
    const profile = record(profileData);
    const companyId = text(profile?.active_company_id, 80);
    const role = text(profile?.role, 40);
    if (!companyId) throw new HttpError("Компания пользователя не определена", 403);
    if (!["employee", "admin", "developer"].includes(role)) {
      throw new HttpError("Кабинет сотрудника недоступен", 403);
    }

    let employee: Row | null = null;
    if (role === "employee") {
      const { data: linkData, error: linkError } = await admin
        .from("employee_account_links")
        .select("person_id")
        .eq("company_id", companyId)
        .eq("user_id", user.id)
        .eq("is_active", true)
        .maybeSingle();
      if (linkError) throw linkError;
      const personId = text(record(linkData)?.person_id, 80);
      if (!personId) throw new HttpError("Рабочая карточка не привязана", 403);

      const { data, error } = await admin
        .from("employees")
        .select("id, person_id, object_id, object_name, fio, position, phone, updated_at")
        .eq("company_id", companyId)
        .eq("person_id", personId)
        .eq("is_active", true)
        .is("archived_at", null)
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (error) throw error;
      employee = record(data);
    } else {
      const requestedEmployeeId = text(input.employee_id, 80);
      if (!requestedEmployeeId) {
        throw new HttpError(
          "Выберите сотрудника для режима просмотра",
          400,
        );
      }
      const { data, error } = await admin
        .from("employees")
        .select("id, person_id, object_id, object_name, fio, position, phone, updated_at")
        .eq("company_id", companyId)
        .eq("id", requestedEmployeeId)
        .eq("is_active", true)
        .is("archived_at", null)
        .maybeSingle();
      if (error) throw error;
      employee = record(data);
    }

    if (!employee) throw new HttpError("Активный сотрудник не найден", 404);
    const employeeId = text(employee.id, 80);
    const objectId = text(employee.object_id, 80);

    const { data: assigneeData, error: assigneeError } = await admin
      .from("task_assignees")
      .select("task_id")
      .eq("company_id", companyId)
      .eq("employee_id", employeeId);
    if (assigneeError) throw assigneeError;
    const taskIds = [...new Set(records(assigneeData).map((row) => text(row.task_id, 80)))]
      .filter(Boolean);

    let tasks: Row[] = [];
    if (taskIds.length > 0) {
      const { data, error } = await admin
        .from("tasks")
        .select(
          "id, task_date, object_id, object_name, axes, work, status, not_done_comment, photo_requirements_enforced, updated_at",
        )
        .eq("company_id", companyId)
        .in("id", taskIds)
        .eq("is_draft", false)
        .is("deleted_at", null)
        .order("task_date", { ascending: false })
        .order("updated_at", { ascending: false })
        .limit(200);
      if (error) throw error;
      tasks = records(data);

      const visibleTaskIds = tasks.map((row) => text(row.id, 80)).filter(Boolean);
      if (visibleTaskIds.length > 0) {
        const { data: photoData, error: photoError } = await admin
          .from("task_photos")
          .select("id, task_id, storage_path, original_name, photo_stage, created_at")
          .eq("company_id", companyId)
          .in("task_id", visibleTaskIds)
          .order("created_at", { ascending: false });
        if (photoError) throw photoError;
        const photos = records(photoData);
        const paths = [...new Set(photos.map((row) => text(row.storage_path, 500)))]
          .filter(Boolean);
        const signedByPath = new Map<string, string>();
        if (paths.length > 0) {
          const { data: signedData } = await admin.storage
            .from("task-photos")
            .createSignedUrls(paths, 60 * 10);
          for (const row of signedData ?? []) {
            const path = text(row.path, 500);
            const signedUrl = text(row.signedUrl, 2000);
            if (path && signedUrl) signedByPath.set(path, signedUrl);
          }
        }
        const photosByTask = new Map<string, Row[]>();
        for (const photo of photos) {
          const taskId = text(photo.task_id, 80);
          const path = text(photo.storage_path, 500);
          const list = photosByTask.get(taskId) ?? [];
          list.push({
            id: photo.id,
            original_name: photo.original_name,
            photo_stage: photo.photo_stage,
            created_at: photo.created_at,
            signed_url: signedByPath.get(path) ?? "",
          });
          photosByTask.set(taskId, list);
        }
        tasks = tasks.map((task) => ({
          ...task,
          photos: photosByTask.get(text(task.id, 80)) ?? [],
        }));
      }
    }

    return json({
      ok: true,
      profile: {
        employee_id: employeeId,
        object_id: objectId,
        full_name: text(employee.fio, 240),
        profession: text(employee.position, 180),
        phone: text(employee.phone, 80),
        current_object: text(employee.object_name, 180),
      },
      tasks,
    });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : String(error);
    console.error("Employee task cabinet failed", {
      status,
      reason: status >= 500 ? "server_error" : "request_rejected",
    });
    return json({ error: message || "Не удалось загрузить задачи" }, status);
  }
});
