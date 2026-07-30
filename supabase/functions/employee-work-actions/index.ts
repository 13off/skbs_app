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
  object_id?: string | null;
  object_name?: string | null;
};

type TaskRow = {
  id: string;
  status?: string | null;
  object_id?: string | null;
  object_name?: string | null;
  task_date?: string | null;
};

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

function numberValue(value: unknown, name: string) {
  const result = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(result)) {
    throw new HttpError(`${name}: передано некорректное значение`, 400);
  }
  return result;
}

function nullableNumber(value: unknown) {
  if (value === null || value === undefined || value === "") return null;
  const result = typeof value === "number" ? value : Number(value);
  return Number.isFinite(result) ? result : null;
}

function coordinateFrom(input: Record<string, unknown>): Coordinate {
  const latitude = numberValue(input.latitude, "Широта");
  const longitude = numberValue(input.longitude, "Долгота");
  const accuracyM = numberValue(input.accuracy_m, "Точность");
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw new HttpError("Координаты находятся вне допустимого диапазона", 400);
  }
  if (accuracyM < 0 || accuracyM > 250) {
    throw new HttpError(
      "Не удалось получить достаточно точное местоположение. Выйдите на открытое место и повторите.",
      422,
    );
  }
  const recordedAtRaw = cleanText(input.recorded_at, 80);
  const recordedAt = recordedAtRaw ? new Date(recordedAtRaw) : new Date();
  if (Number.isNaN(recordedAt.getTime())) {
    throw new HttpError("Некорректное время геопозиции", 400);
  }
  const now = Date.now();
  if (
    recordedAt.getTime() > now + 5 * 60 * 1000 ||
    recordedAt.getTime() < now - 48 * 60 * 60 * 1000
  ) {
    throw new HttpError("Геопозиция слишком старая или имеет неверное время", 400);
  }
  return {
    latitude,
    longitude,
    accuracyM,
    altitudeM: nullableNumber(input.altitude_m),
    speedMps: nullableNumber(input.speed_mps),
    headingDeg: nullableNumber(input.heading_deg),
    isMock: input.is_mock === true,
    recordedAt: recordedAt.toISOString(),
  };
}

function haversineMeters(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number,
) {
  const toRadians = (value: number) => (value * Math.PI) / 180;
  const earthRadius = 6_371_000;
  const deltaLat = toRadians(latitudeB - latitudeA);
  const deltaLon = toRadians(longitudeB - longitudeA);
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(toRadians(latitudeA)) *
      Math.cos(toRadians(latitudeB)) *
      Math.sin(deltaLon / 2) ** 2;
  return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function readBody(request: Request) {
  try {
    const raw = await request.json();
    return raw && typeof raw === "object"
      ? (raw as Record<string, unknown>)
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
  if (!["employee", "admin", "developer", "foreman"].includes(role)) {
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
    .select("id, person_id, object_id, object_name, is_active, archived_at, updated_at")
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
    .select("id, person_id, object_id, object_name, is_active, archived_at, updated_at")
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
  const candidates =
    viewer.role === "employee"
      ? await activeEmployeesForUser(adminClient, viewer)
      : await managerCandidates(adminClient, viewer);
  if (candidates.length === 0) {
    throw new HttpError("Активный сотрудник для просмотра не найден", 404);
  }

  if (requestedEmployeeId) {
    const selected = candidates.find(
      (row) => String(row.id) === requestedEmployeeId,
    );
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
    const selected = candidates.find(
      (row) => String(row.id) === employeeId,
    );
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
  return (
    candidates.find((row) => String(row.id) === recentEmployeeId) ??
    candidates[0]
  );
}

async function assertAssignedTask(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  employee: EmployeeRow,
  taskId: string,
): Promise<TaskRow> {
  const { data: task, error: taskError } = await adminClient
    .from("tasks")
    .select(
      "id, company_id, status, is_draft, deleted_at, object_id, object_name, task_date",
    )
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
  if (!assignment) {
    throw new HttpError("Задача не назначена этому сотруднику", 403);
  }
  return task as TaskRow;
}

async function readGeofence(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  objectId: string,
) {
  const { data, error } = await adminClient
    .from("object_geofences")
    .select("object_id, latitude, longitude, radius_m, updated_at")
    .eq("company_id", viewer.companyId)
    .eq("object_id", objectId)
    .maybeSingle();
  if (error) throw error;
  return data as Record<string, unknown> | null;
}

async function activeShift(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  employeeId: string,
) {
  const { data, error } = await adminClient
    .from("employee_work_shifts")
    .select(
      "id, employee_id, task_id, object_id, work_date, status, started_at, ended_at, " +
        "start_latitude, start_longitude, start_accuracy_m, start_distance_m, " +
        "end_latitude, end_longitude, end_accuracy_m, permission_scope, tracking_mode, " +
        "route_point_count, last_point_at",
    )
    .eq("company_id", viewer.companyId)
    .eq("employee_id", employeeId)
    .eq("status", "active")
    .maybeSingle();
  if (error) throw error;
  return data as Record<string, unknown> | null;
}

async function insertPoint(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  shiftId: string,
  employeeId: string,
  coordinate: Coordinate,
  source: "device" | "start" | "finish",
) {
  const { error } = await adminClient
    .from("employee_work_shift_points")
    .insert({
      company_id: viewer.companyId,
      shift_id: shiftId,
      employee_id: employeeId,
      recorded_at: coordinate.recordedAt,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      accuracy_m: coordinate.accuracyM,
      altitude_m: coordinate.altitudeM,
      speed_mps: coordinate.speedMps,
      heading_deg: coordinate.headingDeg,
      is_mock: coordinate.isMock,
      source,
    });
  if (error) throw error;
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
    if (userError || !user) {
      throw new HttpError("Требуется повторный вход", 401);
    }

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
        object_id: cleanText(employee.object_id, 80),
        object_name: cleanText(employee.object_name, 180),
      });
    }

    if (action === "shift_state") {
      const shift = await activeShift(adminClient, viewer, employee.id);
      const objectId = cleanText(shift?.object_id ?? employee.object_id, 80);
      const geofence = objectId
        ? await readGeofence(adminClient, viewer, objectId)
        : null;
      return json({
        ok: true,
        employee_id: employee.id,
        active_shift: shift,
        geofence,
      });
    }

    if (action === "set_object_geofence") {
      if (!["admin", "developer"].includes(viewer.role)) {
        throw new HttpError(
          "Настраивать геозону может только администратор",
          403,
        );
      }
      const objectId = cleanText(input.object_id, 80);
      if (!objectId) throw new HttpError("Объект не определён", 400);
      const coordinate = coordinateFrom(input);
      const radiusM = Math.round(
        numberValue(input.radius_m ?? 250, "Радиус"),
      );
      if (radiusM < 30 || radiusM > 5000) {
        throw new HttpError(
          "Радиус объекта должен быть от 30 до 5000 метров",
          400,
        );
      }
      const { data: objectRow, error: objectError } = await adminClient
        .from("objects")
        .select("id")
        .eq("id", objectId)
        .eq("company_id", viewer.companyId)
        .maybeSingle();
      if (objectError) throw objectError;
      if (!objectRow) throw new HttpError("Объект не найден", 404);

      const { data: geofence, error } = await adminClient
        .from("object_geofences")
        .upsert(
          {
            company_id: viewer.companyId,
            object_id: objectId,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius_m: radiusM,
            created_by: viewer.userId,
            updated_at: new Date().toISOString(),
          },
          { onConflict: "company_id,object_id" },
        )
        .select("object_id, latitude, longitude, radius_m, updated_at")
        .single();
      if (error) throw error;
      return json({ ok: true, geofence });
    }

    if (action === "route_for_employee") {
      if (!["admin", "developer", "foreman"].includes(viewer.role)) {
        throw new HttpError("Маршрут доступен только руководителю", 403);
      }
      const dateText = cleanText(input.work_date, 20);
      const workDate = /^\d{4}-\d{2}-\d{2}$/.test(dateText)
        ? dateText
        : new Date().toISOString().slice(0, 10);
      const { data: shifts, error: shiftError } = await adminClient
        .from("employee_work_shifts")
        .select(
          "id, employee_id, task_id, object_id, work_date, status, started_at, ended_at, " +
            "start_latitude, start_longitude, start_accuracy_m, start_distance_m, " +
            "end_latitude, end_longitude, end_accuracy_m, permission_scope, tracking_mode, " +
            "route_point_count, last_point_at",
        )
        .eq("company_id", viewer.companyId)
        .eq("employee_id", employee.id)
        .eq("work_date", workDate)
        .order("started_at", { ascending: true });
      if (shiftError) throw shiftError;
      const shiftIds = (shifts ?? []).map(
        (row: Record<string, unknown>) => String(row.id),
      );
      let points: Record<string, unknown>[] = [];
      if (shiftIds.length > 0) {
        const { data: pointRows, error: pointError } = await adminClient
          .from("employee_work_shift_points")
          .select(
            "id, shift_id, recorded_at, latitude, longitude, accuracy_m, altitude_m, " +
              "speed_mps, heading_deg, is_mock, source",
          )
          .eq("company_id", viewer.companyId)
          .in("shift_id", shiftIds)
          .order("recorded_at", { ascending: true })
          .order("id", { ascending: true });
        if (pointError) throw pointError;
        points = (pointRows ?? []) as Record<string, unknown>[];
      }
      const objectIds = [
        ...new Set(
          (shifts ?? [])
            .map((row: Record<string, unknown>) =>
              cleanText(row.object_id, 80),
            )
            .filter(Boolean),
        ),
      ];
      let geofences: Record<string, unknown>[] = [];
      if (objectIds.length > 0) {
        const { data: geofenceRows, error: geofenceError } = await adminClient
          .from("object_geofences")
          .select("object_id, latitude, longitude, radius_m")
          .eq("company_id", viewer.companyId)
          .in("object_id", objectIds);
        if (geofenceError) throw geofenceError;
        geofences = (geofenceRows ?? []) as Record<string, unknown>[];
      }
      return json({
        ok: true,
        employee_id: employee.id,
        work_date: workDate,
        shifts: shifts ?? [],
        points,
        geofences,
      });
    }

    const taskId = cleanText(input.task_id, 80);

    if (action === "start_shift") {
      if (!taskId) {
        throw new HttpError("Сначала выберите рабочую задачу", 400);
      }
      const task = await assertAssignedTask(
        adminClient,
        viewer,
        employee,
        taskId,
      );
      if (cleanText(task.status, 80) === "Выполнено") {
        throw new HttpError(
          "Выполненную задачу нельзя начать заново",
          409,
        );
      }
      const objectId = cleanText(task.object_id || employee.object_id, 80);
      if (!objectId) throw new HttpError("У задачи не определён объект", 400);
      const geofence = await readGeofence(adminClient, viewer, objectId);
      if (!geofence) {
        throw new HttpError(
          "Для объекта не настроена точка начала смены. Обратитесь к руководителю.",
          409,
        );
      }
      const coordinate = coordinateFrom(input);
      if (coordinate.isMock) {
        throw new HttpError(
          "Обнаружена подмена геопозиции. Смена не начата.",
          403,
        );
      }
      const permissionScope = cleanText(input.permission_scope, 30);
      const trackingMode = cleanText(input.tracking_mode, 30);
      if (
        trackingMode === "native_background" &&
        permissionScope !== "always"
      ) {
        throw new HttpError(
          "Разрешите доступ к геопозиции «Всегда», чтобы начать смену.",
          422,
        );
      }
      if (!["native_background", "web_foreground"].includes(trackingMode)) {
        throw new HttpError("Неизвестный режим записи маршрута", 400);
      }
      const distanceM = haversineMeters(
        coordinate.latitude,
        coordinate.longitude,
        Number(geofence.latitude),
        Number(geofence.longitude),
      );
      const radiusM = Number(geofence.radius_m);
      const toleranceM = Math.min(coordinate.accuracyM, 100);
      if (distanceM > radiusM + toleranceM) {
        throw new HttpError(
          `Вы находитесь вне объекта: примерно ${Math.round(
            distanceM,
          )} м до контрольной точки.`,
          422,
        );
      }
      const existing = await activeShift(adminClient, viewer, employee.id);
      if (existing) {
        return json({
          ok: true,
          active_shift: existing,
          already_active: true,
        });
      }
      const { data: shift, error: insertError } = await adminClient
        .from("employee_work_shifts")
        .insert({
          company_id: viewer.companyId,
          employee_id: employee.id,
          task_id: taskId,
          object_id: objectId,
          work_date: new Date().toISOString().slice(0, 10),
          status: "active",
          started_at: coordinate.recordedAt,
          start_latitude: coordinate.latitude,
          start_longitude: coordinate.longitude,
          start_accuracy_m: coordinate.accuracyM,
          start_distance_m: distanceM,
          permission_scope: permissionScope || "unknown",
          tracking_mode: trackingMode,
          route_point_count: 1,
          last_point_at: coordinate.recordedAt,
          started_by: viewer.userId,
        })
        .select(
          "id, employee_id, task_id, object_id, work_date, status, started_at, " +
            "permission_scope, tracking_mode, route_point_count, last_point_at",
        )
        .single();
      if (insertError) throw insertError;
      await insertPoint(
        adminClient,
        viewer,
        String(shift.id),
        employee.id,
        coordinate,
        "start",
      );
      const { error: taskUpdateError } = await adminClient
        .from("tasks")
        .update({
          status: "В работе",
          updated_at: new Date().toISOString(),
        })
        .eq("id", taskId)
        .eq("company_id", viewer.companyId);
      if (taskUpdateError) throw taskUpdateError;
      return json({ ok: true, active_shift: shift, distance_m: distanceM });
    }

    if (action === "append_route_points") {
      const shift = await activeShift(adminClient, viewer, employee.id);
      if (!shift) throw new HttpError("Активная смена не найдена", 409);
      const rawPoints = Array.isArray(input.points)
        ? input.points.slice(0, 100)
        : [];
      if (rawPoints.length === 0) return json({ ok: true, inserted: 0 });
      const points = rawPoints
        .filter((row) => row && typeof row === "object")
        .map((row) => coordinateFrom(row as Record<string, unknown>))
        .filter((point) => !point.isMock);
      if (points.length === 0) return json({ ok: true, inserted: 0 });
      const rows = points.map((point) => ({
        company_id: viewer.companyId,
        shift_id: String(shift.id),
        employee_id: employee.id,
        recorded_at: point.recordedAt,
        latitude: point.latitude,
        longitude: point.longitude,
        accuracy_m: point.accuracyM,
        altitude_m: point.altitudeM,
        speed_mps: point.speedMps,
        heading_deg: point.headingDeg,
        is_mock: point.isMock,
        source: "device",
      }));
      const { error: pointError } = await adminClient
        .from("employee_work_shift_points")
        .insert(rows);
      if (pointError) throw pointError;
      const lastPoint = points[points.length - 1];
      const { error: shiftUpdateError } = await adminClient
        .from("employee_work_shifts")
        .update({
          route_point_count:
            Number(shift.route_point_count ?? 0) + points.length,
          last_point_at: lastPoint.recordedAt,
          updated_at: new Date().toISOString(),
        })
        .eq("id", String(shift.id))
        .eq("company_id", viewer.companyId)
        .eq("status", "active");
      if (shiftUpdateError) throw shiftUpdateError;
      return json({ ok: true, inserted: points.length });
    }

    if (action === "finish_shift") {
      const shift = await activeShift(adminClient, viewer, employee.id);
      if (!shift) throw new HttpError("Активная смена не найдена", 409);
      const coordinate = coordinateFrom(input);
      if (coordinate.isMock) {
        throw new HttpError(
          "Обнаружена подмена геопозиции. Завершение смены отклонено.",
          403,
        );
      }
      await insertPoint(
        adminClient,
        viewer,
        String(shift.id),
        employee.id,
        coordinate,
        "finish",
      );
      const { data: completedShift, error: finishError } = await adminClient
        .from("employee_work_shifts")
        .update({
          status: "completed",
          ended_at: coordinate.recordedAt,
          end_latitude: coordinate.latitude,
          end_longitude: coordinate.longitude,
          end_accuracy_m: coordinate.accuracyM,
          route_point_count: Number(shift.route_point_count ?? 0) + 1,
          last_point_at: coordinate.recordedAt,
          ended_by: viewer.userId,
          updated_at: new Date().toISOString(),
        })
        .eq("id", String(shift.id))
        .eq("company_id", viewer.companyId)
        .eq("status", "active")
        .select(
          "id, employee_id, task_id, object_id, work_date, status, started_at, ended_at, " +
            "permission_scope, tracking_mode, route_point_count, last_point_at",
        )
        .single();
      if (finishError) throw finishError;
      return json({ ok: true, completed_shift: completedShift });
    }

    if (!taskId) throw new HttpError("Задача не определена", 400);
    const task = await assertAssignedTask(
      adminClient,
      viewer,
      employee,
      taskId,
    );

    if (action === "start_task") {
      throw new HttpError(
        "Работа начинается только через кнопку «Начать смену» с проверкой геопозиции.",
        409,
      );
    }

    if (action === "upload_task_photo") {
      if (cleanText(task.status, 80) === "Выполнено") {
        throw new HttpError(
          "Выполненная задача закрыта для новых фотографий",
          409,
        );
      }
      const stage = cleanText(input.photo_stage, 20);
      if (stage !== "before" && stage !== "after") {
        throw new HttpError("Неизвестный тип фотографии", 400);
      }
      const contentType = cleanText(input.content_type, 80).toLowerCase();
      const allowedTypes = new Set([
        "image/jpeg",
        "image/png",
        "image/webp",
      ]);
      if (!allowedTypes.has(contentType)) {
        throw new HttpError("Можно загрузить только JPG, PNG или WEBP", 400);
      }
      const base64 = cleanText(input.base64, 8_000_000);
      const bytes = decodePhoto(base64);
      if (bytes.length === 0 || bytes.length > 5 * 1024 * 1024) {
        throw new HttpError(
          "Размер фотографии должен быть не более 5 МБ",
          400,
        );
      }
      const extensionByType: Record<string, string> = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
      };
      const extension = extensionByType[contentType];
      const storagePath = `${taskId}/${stage}/${Date.now()}_${crypto.randomUUID()}.${extension}`;
      const originalName =
        cleanText(input.original_name, 240) || `photo.${extension}`;

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
    return json(
      { error: message || "Не удалось выполнить действие" },
      status,
    );
  }
});
