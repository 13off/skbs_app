import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Row = Record<string, unknown>;
type Viewer = { userId: string; companyId: string; role: string };
type EmployeeRow = { id: string; objectId: string; personId: string };
type Coordinate = {
  latitude: number;
  longitude: number;
  accuracyM: number;
  altitudeM: number | null;
  speedMps: number | null;
  headingDeg: number | null;
  isMock: boolean;
  recordedAt: string;
};

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
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function record(value: unknown): Row | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Row;
}

function records(value: unknown): Row[] {
  if (!Array.isArray(value)) return [];
  return value.map(record).filter((item): item is Row => item !== null);
}

function numberValue(value: unknown, field: string) {
  const result = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(result)) {
    throw new HttpError(`${field}: некорректное значение`, 400);
  }
  return result;
}

function nullableNumber(value: unknown) {
  if (value === null || value === undefined || value === "") return null;
  const result = typeof value === "number" ? value : Number(value);
  return Number.isFinite(result) ? result : null;
}

function coordinateFrom(input: Row): Coordinate {
  const latitude = numberValue(input.latitude, "Широта");
  const longitude = numberValue(input.longitude, "Долгота");
  const accuracyM = numberValue(input.accuracy_m, "Точность");
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw new HttpError("Координаты вне допустимого диапазона", 400);
  }
  if (accuracyM < 0 || accuracyM > 250) {
    throw new HttpError(
      "Не удалось точно определить местоположение. Выйдите на открытое место и повторите.",
      422,
    );
  }
  const rawTime = text(input.recorded_at, 80);
  const date = rawTime ? new Date(rawTime) : new Date();
  if (Number.isNaN(date.getTime())) {
    throw new HttpError("Некорректное время геопозиции", 400);
  }
  const now = Date.now();
  if (date.getTime() > now + 5 * 60 * 1000 || date.getTime() < now - 48 * 60 * 60 * 1000) {
    throw new HttpError("Геопозиция имеет неверное время", 400);
  }
  return {
    latitude,
    longitude,
    accuracyM,
    altitudeM: nullableNumber(input.altitude_m),
    speedMps: nullableNumber(input.speed_mps),
    headingDeg: nullableNumber(input.heading_deg),
    isMock: input.is_mock === true,
    recordedAt: date.toISOString(),
  };
}

async function readBody(request: Request): Promise<Row> {
  try {
    return record(await request.json()) ?? {};
  } catch {
    return {};
  }
}

async function readViewer(
  // deno-lint-ignore no-explicit-any
  admin: any,
  userId: string,
): Promise<Viewer> {
  const { data, error } = await admin
    .from("user_profiles")
    .select("role, active_company_id, is_active")
    .eq("id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (error) throw error;
  const profile = record(data);
  const companyId = text(profile?.active_company_id, 80);
  const role = text(profile?.role, 40);
  if (!companyId) throw new HttpError("Компания пользователя не определена", 403);
  if (!["employee", "admin", "developer", "foreman"].includes(role)) {
    throw new HttpError("Рабочие действия недоступны", 403);
  }
  return { userId, companyId, role };
}

async function resolveEmployee(
  // deno-lint-ignore no-explicit-any
  admin: any,
  viewer: Viewer,
  requestedEmployeeId: string,
): Promise<EmployeeRow> {
  if (viewer.role === "employee") {
    const { data: linkData, error: linkError } = await admin
      .from("employee_account_links")
      .select("person_id")
      .eq("company_id", viewer.companyId)
      .eq("user_id", viewer.userId)
      .eq("is_active", true)
      .maybeSingle();
    if (linkError) throw linkError;
    const personId = text(record(linkData)?.person_id, 80);
    if (!personId) throw new HttpError("Рабочая карточка не привязана", 403);

    const { data, error } = await admin
      .from("employees")
      .select("id, person_id, object_id, updated_at")
      .eq("company_id", viewer.companyId)
      .eq("person_id", personId)
      .eq("is_active", true)
      .is("archived_at", null)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    const employee = record(data);
    if (!employee) throw new HttpError("Активная карточка сотрудника не найдена", 404);
    const id = text(employee.id, 80);
    if (requestedEmployeeId && requestedEmployeeId !== id) {
      throw new HttpError("Нельзя выполнять действия от имени другого сотрудника", 403);
    }
    return {
      id,
      personId: text(employee.person_id, 80),
      objectId: text(employee.object_id, 80),
    };
  }

  if (!requestedEmployeeId) {
    throw new HttpError("Выберите сотрудника", 400);
  }
  const { data, error } = await admin
    .from("employees")
    .select("id, person_id, object_id")
    .eq("company_id", viewer.companyId)
    .eq("id", requestedEmployeeId)
    .eq("is_active", true)
    .is("archived_at", null)
    .maybeSingle();
  if (error) throw error;
  const employee = record(data);
  if (!employee) throw new HttpError("Сотрудник не найден", 404);
  return {
    id: text(employee.id, 80),
    personId: text(employee.person_id, 80),
    objectId: text(employee.object_id, 80),
  };
}

async function activeShift(
  // deno-lint-ignore no-explicit-any
  admin: any,
  viewer: Viewer,
  employeeId: string,
) {
  const { data, error } = await admin
    .from("employee_work_shifts")
    .select(
      "id, employee_id, task_id, object_id, work_date, status, started_at, ended_at, " +
        "start_latitude, start_longitude, end_latitude, end_longitude, " +
        "permission_scope, tracking_mode, route_point_count, last_point_at",
    )
    .eq("company_id", viewer.companyId)
    .eq("employee_id", employeeId)
    .eq("status", "active")
    .maybeSingle();
  if (error) throw error;
  return record(data);
}

async function savePoint(
  // deno-lint-ignore no-explicit-any
  admin: any,
  viewer: Viewer,
  shiftId: string,
  employeeId: string,
  point: Coordinate,
  source: "start" | "device" | "finish",
) {
  const { error } = await admin.from("employee_work_shift_points").insert({
    company_id: viewer.companyId,
    shift_id: shiftId,
    employee_id: employeeId,
    recorded_at: point.recordedAt,
    latitude: point.latitude,
    longitude: point.longitude,
    accuracy_m: point.accuracyM,
    altitude_m: point.altitudeM,
    speed_mps: point.speedMps,
    heading_deg: point.headingDeg,
    is_mock: point.isMock,
    source,
  });
  if (error) throw error;
}

async function assignedTask(
  // deno-lint-ignore no-explicit-any
  admin: any,
  viewer: Viewer,
  employeeId: string,
  taskId: string,
) {
  const { data: assignmentData, error: assignmentError } = await admin
    .from("task_assignees")
    .select("task_id")
    .eq("company_id", viewer.companyId)
    .eq("employee_id", employeeId)
    .eq("task_id", taskId)
    .maybeSingle();
  if (assignmentError) throw assignmentError;
  if (!record(assignmentData)) {
    throw new HttpError("Задача не назначена этому сотруднику", 403);
  }
  const { data, error } = await admin
    .from("tasks")
    .select("id, status, photo_requirements_enforced")
    .eq("company_id", viewer.companyId)
    .eq("id", taskId)
    .eq("is_draft", false)
    .is("deleted_at", null)
    .maybeSingle();
  if (error) throw error;
  const task = record(data);
  if (!task) throw new HttpError("Задача не найдена", 404);
  return task;
}

function decodePhoto(value: string) {
  try {
    const binary = atob(value);
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
      throw new HttpError("Рабочие действия не настроены", 500);
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
    const viewer = await readViewer(admin, user.id);
    const input = await readBody(request);
    const action = text(input.action, 50);
    const requestedEmployeeId = text(input.employee_id, 80);
    const employee = await resolveEmployee(admin, viewer, requestedEmployeeId);

    if (action === "shift_state") {
      return json({
        ok: true,
        employee_id: employee.id,
        active_shift: await activeShift(admin, viewer, employee.id),
      });
    }

    if (action === "start_shift") {
      if (!employee.objectId) {
        throw new HttpError("У сотрудника не указан объект", 400);
      }
      const existing = await activeShift(admin, viewer, employee.id);
      if (existing) {
        return json({ ok: true, active_shift: existing, already_active: true });
      }
      const point = coordinateFrom(input);
      if (point.isMock) {
        throw new HttpError("Обнаружена подмена геопозиции", 403);
      }
      const permissionScope = text(input.permission_scope, 30);
      const trackingMode = text(input.tracking_mode, 30);
      if (trackingMode === "native_background" && permissionScope !== "always") {
        throw new HttpError("Разрешите приложению доступ к геопозиции всегда", 422);
      }
      if (!["native_background", "web_foreground"].includes(trackingMode)) {
        throw new HttpError("Неизвестный режим рабочего дня", 400);
      }
      const requestedDate = text(input.work_date, 20);
      const workDate = /^\d{4}-\d{2}-\d{2}$/.test(requestedDate)
        ? requestedDate
        : new Date().toISOString().slice(0, 10);
      const { data, error } = await admin
        .from("employee_work_shifts")
        .insert({
          company_id: viewer.companyId,
          employee_id: employee.id,
          task_id: null,
          object_id: employee.objectId,
          work_date: workDate,
          status: "active",
          started_at: point.recordedAt,
          start_latitude: point.latitude,
          start_longitude: point.longitude,
          start_accuracy_m: point.accuracyM,
          start_distance_m: null,
          permission_scope: permissionScope || "unknown",
          tracking_mode: trackingMode,
          route_point_count: 1,
          last_point_at: point.recordedAt,
          started_by: viewer.userId,
        })
        .select(
          "id, employee_id, task_id, object_id, work_date, status, started_at, ended_at, " +
            "start_latitude, start_longitude, end_latitude, end_longitude, " +
            "permission_scope, tracking_mode, route_point_count, last_point_at",
        )
        .single();
      if (error) throw error;
      const shift = record(data);
      if (!shift) throw new HttpError("Рабочий день не был начат", 500);
      await savePoint(admin, viewer, text(shift.id, 80), employee.id, point, "start");
      return json({ ok: true, active_shift: shift });
    }

    if (action === "append_route_points") {
      const shift = await activeShift(admin, viewer, employee.id);
      if (!shift) throw new HttpError("Рабочий день не начат", 409);
      const rawPoints = Array.isArray(input.points) ? input.points.slice(0, 100) : [];
      const points = rawPoints
        .map(record)
        .filter((item): item is Row => item !== null)
        .map(coordinateFrom)
        .filter((point) => !point.isMock);
      if (points.length === 0) return json({ ok: true, inserted: 0 });

      const shiftId = text(shift.id, 80);
      const { error: insertError } = await admin
        .from("employee_work_shift_points")
        .insert(points.map((point) => ({
          company_id: viewer.companyId,
          shift_id: shiftId,
          employee_id: employee.id,
          recorded_at: point.recordedAt,
          latitude: point.latitude,
          longitude: point.longitude,
          accuracy_m: point.accuracyM,
          altitude_m: point.altitudeM,
          speed_mps: point.speedMps,
          heading_deg: point.headingDeg,
          is_mock: false,
          source: "device",
        })));
      if (insertError) throw insertError;
      const last = points[points.length - 1];
      const currentCount = Number(shift.route_point_count ?? 0);
      const { error: updateError } = await admin
        .from("employee_work_shifts")
        .update({
          route_point_count: (Number.isFinite(currentCount) ? currentCount : 0) + points.length,
          last_point_at: last.recordedAt,
          updated_at: new Date().toISOString(),
        })
        .eq("id", shiftId)
        .eq("company_id", viewer.companyId)
        .eq("status", "active");
      if (updateError) throw updateError;
      return json({ ok: true, inserted: points.length });
    }

    if (action === "finish_shift") {
      const shift = await activeShift(admin, viewer, employee.id);
      if (!shift) throw new HttpError("Рабочий день не начат", 409);
      const point = coordinateFrom(input);
      if (point.isMock) throw new HttpError("Обнаружена подмена геопозиции", 403);
      const shiftId = text(shift.id, 80);
      await savePoint(admin, viewer, shiftId, employee.id, point, "finish");
      const currentCount = Number(shift.route_point_count ?? 0);
      const { data, error } = await admin
        .from("employee_work_shifts")
        .update({
          status: "completed",
          ended_at: point.recordedAt,
          end_latitude: point.latitude,
          end_longitude: point.longitude,
          end_accuracy_m: point.accuracyM,
          route_point_count: (Number.isFinite(currentCount) ? currentCount : 0) + 1,
          last_point_at: point.recordedAt,
          ended_by: viewer.userId,
          updated_at: new Date().toISOString(),
        })
        .eq("id", shiftId)
        .eq("company_id", viewer.companyId)
        .eq("status", "active")
        .select(
          "id, employee_id, task_id, object_id, work_date, status, started_at, ended_at, " +
            "start_latitude, start_longitude, end_latitude, end_longitude, " +
            "permission_scope, tracking_mode, route_point_count, last_point_at",
        )
        .single();
      if (error) throw error;
      return json({ ok: true, completed_shift: record(data) });
    }

    if (action === "route_for_employee") {
      if (!["admin", "developer", "foreman"].includes(viewer.role)) {
        throw new HttpError("Маршруты доступны только руководителю", 403);
      }
      const requestedDate = text(input.work_date, 20);
      const workDate = /^\d{4}-\d{2}-\d{2}$/.test(requestedDate)
        ? requestedDate
        : new Date().toISOString().slice(0, 10);
      const { data: shiftData, error: shiftError } = await admin
        .from("employee_work_shifts")
        .select(
          "id, employee_id, task_id, object_id, work_date, status, started_at, ended_at, " +
            "start_latitude, start_longitude, end_latitude, end_longitude, " +
            "permission_scope, tracking_mode, route_point_count, last_point_at",
        )
        .eq("company_id", viewer.companyId)
        .eq("employee_id", employee.id)
        .eq("work_date", workDate)
        .order("started_at", { ascending: true });
      if (shiftError) throw shiftError;
      const shifts = records(shiftData);
      const shiftIds = shifts.map((row) => text(row.id, 80)).filter(Boolean);
      let points: Row[] = [];
      if (shiftIds.length > 0) {
        const { data, error } = await admin
          .from("employee_work_shift_points")
          .select(
            "id, shift_id, recorded_at, latitude, longitude, accuracy_m, altitude_m, speed_mps, heading_deg, is_mock, source",
          )
          .eq("company_id", viewer.companyId)
          .in("shift_id", shiftIds)
          .order("recorded_at", { ascending: true })
          .order("id", { ascending: true });
        if (error) throw error;
        points = records(data);
      }
      return json({
        ok: true,
        employee_id: employee.id,
        work_date: workDate,
        shifts,
        points,
      });
    }

    const taskId = text(input.task_id, 80);
    if (!taskId) throw new HttpError("Задача не определена", 400);
    const task = await assignedTask(admin, viewer, employee.id, taskId);

    if (action === "start_task") {
      const shift = await activeShift(admin, viewer, employee.id);
      if (!shift) throw new HttpError("Сначала начните рабочий день", 409);
      const currentStatus = text(task.status, 80);
      if (currentStatus === "Выполнено") {
        throw new HttpError("Выполненную задачу нельзя начать заново", 409);
      }
      if (currentStatus !== "В работе") {
        const { error } = await admin
          .from("tasks")
          .update({ status: "В работе", updated_at: new Date().toISOString() })
          .eq("company_id", viewer.companyId)
          .eq("id", taskId);
        if (error) throw error;
      }
      return json({ ok: true, status: "В работе" });
    }

    if (action === "upload_task_photo") {
      const shift = await activeShift(admin, viewer, employee.id);
      if (!shift) throw new HttpError("Сначала начните рабочий день", 409);
      if (text(task.status, 80) !== "В работе") {
        throw new HttpError("Сначала нажмите «Начать выполнение»", 409);
      }
      const stage = text(input.photo_stage, 20);
      if (stage !== "before" && stage !== "after") {
        throw new HttpError("Неизвестный тип фотографии", 400);
      }
      const contentType = text(input.content_type, 80).toLowerCase();
      const extensions: Record<string, string> = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
      };
      const extension = extensions[contentType];
      if (!extension) throw new HttpError("Можно загрузить только JPG, PNG или WEBP", 400);
      const bytes = decodePhoto(text(input.base64, 8_000_000));
      if (bytes.length === 0 || bytes.length > 5 * 1024 * 1024) {
        throw new HttpError("Размер фотографии должен быть не более 5 МБ", 400);
      }
      const path = `${taskId}/${stage}/${Date.now()}_${crypto.randomUUID()}.${extension}`;
      const originalName = text(input.original_name, 240) || `photo.${extension}`;
      const { error: uploadError } = await admin.storage
        .from("task-photos")
        .upload(path, bytes, { contentType, upsert: false });
      if (uploadError) throw uploadError;
      const { data, error } = await admin
        .from("task_photos")
        .insert({
          company_id: viewer.companyId,
          task_id: taskId,
          storage_path: path,
          original_name: originalName,
          photo_stage: stage,
        })
        .select("id, task_id, photo_stage, original_name, created_at")
        .single();
      if (error) {
        await admin.storage.from("task-photos").remove([path]);
        throw error;
      }
      return json({ ok: true, photo: record(data) });
    }

    throw new HttpError("Неизвестное действие", 400);
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : String(error);
    console.error("Employee shift action failed", {
      status,
      reason: status >= 500 ? "server_error" : "request_rejected",
    });
    return json({ error: message || "Не удалось выполнить действие" }, status);
  }
});
