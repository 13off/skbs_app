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

type EmployeeRow = {
  id: string;
  person_id?: string | null;
  object_name?: string | null;
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

function cleanText(value: unknown, maxLength = 500) {
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
  const role = cleanText(data.role, 40);
  if (!["employee", "admin", "developer"].includes(role)) {
    throw new HttpError("Рабочие действия сотрудника недоступны", 403);
  }
  return {
    userId,
    role,
    companyId: String(data.active_company_id),
  };
}

async function activeEmployeesForUser(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
): Promise<EmployeeRow[]> {
  const { data: link, error: linkError } = await adminClient
    .from("employee_account_links")
    .select("person_id")
    .eq("company_id", viewer.companyId)
    .eq("user_id", viewer.userId)
    .eq("is_active", true)
    .maybeSingle();
  if (linkError) throw linkError;
  if (!link?.person_id) {
    throw new HttpError("Связь с рабочей карточкой не найдена", 403);
  }

  const { data, error } = await adminClient
    .from("employees")
    .select("id, person_id, object_name, is_active, archived_at, updated_at")
    .eq("company_id", viewer.companyId)
    .eq("person_id", String(link.person_id))
    .eq("is_active", true)
    .is("archived_at", null)
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as EmployeeRow[];
}

async function managerCandidates(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
): Promise<EmployeeRow[]> {
  const { data, error } = await adminClient
    .from("employees")
    .select("id, person_id, object_name, is_active, archived_at, updated_at")
    .eq("company_id", viewer.companyId)
    .eq("is_active", true)
    .is("archived_at", null)
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as EmployeeRow[];
}

async function resolveEmployee(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  input: Record<string, unknown>,
): Promise<EmployeeRow> {
  const taskId = cleanText(input.task_id, 80);
  const requestedEmployeeId = cleanText(input.employee_id, 80);
  const candidates = viewer.role === "employee"
    ? await activeEmployeesForUser(adminClient, viewer)
    : await managerCandidates(adminClient, viewer);
  if (candidates.length === 0) {
    throw new HttpError("Активный сотрудник для просмотра не найден", 404);
  }

  if (requestedEmployeeId) {
    const selected = candidates.find((row) => String(row.id) === requestedEmployeeId);
    if (!selected) throw new HttpError("Выбранный сотрудник недоступен", 404);
    return selected;
  }

  if (taskId) {
    const candidateIds = candidates.map((row) => String(row.id));
    const { data: assignment, error: assignmentError } = await adminClient
      .from("task_assignees")
      .select("employee_id")
      .eq("company_id", viewer.companyId)
      .eq("task_id", taskId)
      .in("employee_id", candidateIds)
      .limit(1)
      .maybeSingle();
    if (assignmentError) throw assignmentError;
    const employeeId = cleanText(assignment?.employee_id, 80);
    const selected = candidates.find((row) => String(row.id) === employeeId);
    if (selected) return selected;
  }

  const candidateIds = candidates.map((row) => String(row.id));
  const { data: recentAssignments, error: recentError } = await adminClient
    .from("task_assignees")
    .select("employee_id, created_at")
    .eq("company_id", viewer.companyId)
    .in("employee_id", candidateIds)
    .order("created_at", { ascending: false })
    .limit(100);
  if (recentError) throw recentError;
  const recentEmployeeId = cleanText(recentAssignments?.[0]?.employee_id, 80);
  return candidates.find((row) => String(row.id) === recentEmployeeId) ?? candidates[0];
}

async function assertAssignedTask(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  employee: EmployeeRow,
  taskId: string,
) {
  const { data: task, error: taskError } = await adminClient
    .from("tasks")
    .select("id, company_id, status, is_draft, deleted_at")
    .eq("id", taskId)
    .eq("company_id", viewer.companyId)
    .eq("is_draft", false)
    .is("deleted_at", null)
    .maybeSingle();
  if (taskError) throw taskError;
  if (!task) throw new HttpError("Задача не найдена", 404);

  const { data: assignment, error: assignmentError } = await adminClient
    .from("task_assignees")
    .select("task_id")
    .eq("company_id", viewer.companyId)
    .eq("task_id", taskId)
    .eq("employee_id", employee.id)
    .maybeSingle();
  if (assignmentError) throw assignmentError;
  if (!assignment) throw new HttpError("Задача не назначена этому сотруднику", 403);
  return task as Record<string, unknown>;
}

function decodePhoto(base64: string) {
  try {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index++) {
      bytes[index] = binary.charCodeAt(index);
    }
    return bytes;
  } catch {
    throw new HttpError("Не удалось прочитать фотографию", 400);
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
      throw new HttpError("Рабочие действия сотрудника не настроены", 500);
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

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const viewer = await readViewer(adminClient, user.id);
    const input = await readBody(request);
    const action = cleanText(input.action, 40) || "resolve_selection";
    const employee = await resolveEmployee(adminClient, viewer, input);

    if (action === "resolve_selection") {
      return json({
        ok: true,
        employee_id: employee.id,
        object_name: cleanText(employee.object_name, 180),
      });
    }

    const taskId = cleanText(input.task_id, 80);
    if (!taskId) throw new HttpError("Задача не определена", 400);
    const task = await assertAssignedTask(adminClient, viewer, employee, taskId);

    if (action === "start_task") {
      if (cleanText(task.status, 80) === "Выполнено") {
        throw new HttpError("Выполненную задачу нельзя начать заново", 409);
      }
      const { error } = await adminClient
        .from("tasks")
        .update({
          status: "В работе",
          updated_at: new Date().toISOString(),
        })
        .eq("id", taskId)
        .eq("company_id", viewer.companyId);
      if (error) throw error;
      return json({ ok: true, status: "В работе" });
    }

    if (action === "upload_task_photo") {
      if (cleanText(task.status, 80) === "Выполнено") {
        throw new HttpError("Выполненная задача закрыта для новых фотографий", 409);
      }
      const stage = cleanText(input.photo_stage, 20);
      if (stage !== "before" && stage !== "after") {
        throw new HttpError("Неизвестный тип фотографии", 400);
      }
      const contentType = cleanText(input.content_type, 80).toLowerCase();
      const allowedTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
      if (!allowedTypes.has(contentType)) {
        throw new HttpError("Можно загрузить только JPG, PNG или WEBP", 400);
      }
      const base64 = cleanText(input.base64, 8_000_000);
      const bytes = decodePhoto(base64);
      if (bytes.length === 0 || bytes.length > 5 * 1024 * 1024) {
        throw new HttpError("Размер фотографии должен быть не более 5 МБ", 400);
      }
      const extensionByType: Record<string, string> = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
      };
      const extension = extensionByType[contentType];
      const storagePath = `${taskId}/${stage}/${Date.now()}_${crypto.randomUUID()}.${extension}`;
      const originalName = cleanText(input.original_name, 240) || `photo.${extension}`;

      const { error: uploadError } = await adminClient.storage
        .from("task-photos")
        .upload(storagePath, bytes, { contentType, upsert: false });
      if (uploadError) throw uploadError;

      const { data: photo, error: insertError } = await adminClient
        .from("task_photos")
        .insert({
          task_id: taskId,
          company_id: viewer.companyId,
          storage_path: storagePath,
          original_name: originalName,
          photo_stage: stage,
        })
        .select("id, task_id, photo_stage, original_name, created_at")
        .single();
      if (insertError) {
        await adminClient.storage.from("task-photos").remove([storagePath]);
        throw insertError;
      }
      return json({ ok: true, photo });
    }

    throw new HttpError("Неизвестное действие", 400);
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : String(error);
    console.error("Employee work action failed", {
      status,
      reason: status >= 500 ? "server_error" : "request_rejected",
    });
    return json({ error: message || "Не удалось выполнить действие" }, status);
  }
});
