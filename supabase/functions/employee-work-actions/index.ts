import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type DbRow = Record<string, unknown>;
type Viewer = { userId: string; role: string; companyId: string };
type EmployeeRow = {
  id: string;
  personId: string;
  objectId: string;
  objectName: string;
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

function cleanText(value: unknown, maxLength = 500) {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function asRecord(value: unknown): DbRow | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as DbRow;
}

function asRecords(value: unknown): DbRow[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => asRecord(item))
    .filter((item): item is DbRow => item !== null);
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

function coordinateFrom(input: DbRow): Coordinate {
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
  const rawTime = cleanText(input.recorded_at, 80);
  const time = rawTime ? new Date(rawTime) : new Date();
  if (Number.isNaN(time.getTime())) {
    throw new HttpError("Некорректное время геопозиции", 400);
  }
  const now = Date.now();
  if (
    time.getTime() > now + 5 * 60 * 1000 ||
    time.getTime() < now - 48 * 60 * 60 * 1000
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
    recordedAt: time.toISOString(),
  };
}

function haversineMeters(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number,
) {
  const radians = (value: number) => (value * Math.PI) / 180;
  const deltaLat = radians(latitudeB - latitudeA);
  const deltaLon = radians(longitudeB - longitudeA);
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(radians(latitudeA)) *
      Math.cos(radians(latitudeB)) *
      Math.sin(deltaLon / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function readBody(request: Request): Promise<DbRow> {
  try {
    return asRecord(await request.json()) ?? {};
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
    .select("role, active_company_id, is_active")
    .eq("id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (error) throw error;
  const profile = asRecord(data);
  const companyId = cleanText(profile?.active_company_id, 80);
  const role = cleanText(profile?.role, 40);
  if (!companyId) throw new HttpError("Компания пользователя не определена", 403);
  if (!["employee", "admin", "developer", "foreman"].includes(role)) {
    throw new HttpError("Рабочие действия сотрудника недоступны", 403);
  }
  return { userId, role, companyId };
}

async function employeeCandidates(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
): Promise<EmployeeRow[]> {
  let personId = "";
  if (viewer.role === "employee") {
    const { data, error } = await adminClient
      .from("employee_account_links")
      .select("person_id")
      .eq("company_id", viewer.companyId)
      .eq("user_id", viewer.userId)
      .eq("is_active", true)
      .maybeSingle();
    if (error) throw error;
    personId = cleanText(asRecord(data)?.person_id, 80);
    if (!personId) {
      throw new HttpError("Связь с рабочей карточкой не найдена", 403);
    }
  }

  let query = adminClient
    .from("employees")
    .select("id, person_id, object_id, object_name, updated_at")
    .eq("company_id", viewer.companyId)
    .eq("is_active", true)
    .is("archived_at", null)
    .order("updated_at", { ascending: false });
  if (personId) query = query.eq("person_id", personId);
  const { data, error } = await query;
  if (error) throw error;
  return asRecords(data)
    .map((row) => ({
      id: cleanText(row.id, 80),
      personId: cleanText(row.person_id, 80),
      objectId: cleanText(row.object_id, 80),
      objectName: cleanText(row.object_name, 180),
    }))
    .filter((row) => row.id);
}

async function resolveEmployee(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  input: DbRow,
): Promise<EmployeeRow> {
  const candidates = await employeeCandidates(adminClient, viewer);
  if (candidates.length === 0) {
    throw new HttpError("Активный сотрудник для просмотра не найден", 404);
  }
  const requestedId = cleanText(input.employee_id, 80);
  if (requestedId) {
    const selected = candidates.find((row) => row.id === requestedId);
    if (!selected) throw new HttpError("Выбранный сотрудник недоступен", 404);
    return selected;
  }

  const taskId = cleanText(input.task_id, 80);
  const candidateIds = candidates.map((row) => row.id);
  if (taskId) {
    const { data, error } = await adminClient
      .from("task_assignees")
      .select("employee_id")
      .eq("company_id", viewer.companyId)
      .eq("task_id", taskId)
      .in("employee_id", candidateIds)
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    const assignedId = cleanText(asRecord(data)?.employee_id, 80);
    const assigned = candidates.find((row) => row.id === assignedId);
    if (assigned) return assigned;
  }

  const { data, error } = await adminClient
    .from("task_assignees")
    .select("employee_id, created_at")
    .eq("company_id", viewer.companyId)
    .in("employee_id", candidateIds)
    .order("created_at", { ascending: false })
    .limit(1);
  if (error) throw error;
  const recentId = cleanText(asRecords(data)[0]?.employee_id, 80);
  return candidates.find((row) => row.id === recentId) ?? candidates[0];
}

async function assignedTask(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  employee: EmployeeRow,
  taskId: string,
): Promise<DbRow> {
  const { data: taskData, error: taskError } = await adminClient
    .from("tasks")
    .select("id, status, object_id, object_name, task_date, is_draft, deleted_at")
    .eq("id", taskId)
    .eq("company_id", viewer.companyId)
    .eq("is_draft", false)
    .is("deleted_at", null)
    .maybeSingle();
  if (taskError) throw taskError;
  const task = asRecord(taskData);
  if (!task) throw new HttpError("Задача не найдена", 404);

  const { data, error } = await adminClient
    .from("task_assignees")
    .select("task_id")
    .eq("company_id", viewer.companyId)
    .eq("task_id", taskId)
    .eq("employee_id", employee.id)
    .maybeSingle();
  if (error) throw error;
  if (!asRecord(data)) {
    throw new HttpError("Задача не назначена этому сотруднику", 403);
  }
  return task;
}

async function getActiveShift(
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
  return asRecord(data);
}

async function getGeofence(
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
  return asRecord(data);
}

async function savePoint(
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  viewer: Viewer,
  shiftId: string,
  employeeId: string,
  point: Coordinate,
  source: "device" | "start" | "finish",
) {
  const { error } = await adminClient
    .from("employee_work_shift_points")
    .insert({
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

function assertSameObject(task: DbRow, shift: DbRow) {
  const taskObjectId = cleanText(task.object_id, 80);
  const shiftObjectId = cleanText(shift.object_id, 80);
  if (!taskObjectId || !shiftObjectId || taskObjectId !== shiftObjectId) {
    throw new HttpError("Задача относится к другому объекту", 409);
  }
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
        object_id: employee.objectId,
        object_name: employee.objectName,
      });
    }

    if (action === "shift_state") {
      const shift = await getActiveShift(adminClient, viewer, employee.id);
      const objectId = cleanText(shift?.object_id ?? employee.objectId, 80);
      const geofence = objectId
        ? await getGeofence(adminClient, viewer, objectId)
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
        throw new HttpError("Настраивать геозону может только администратор", 403);
      }
      const objectId = cleanText(input.object_id, 80);
      if (!objectId) throw new HttpError("Объект не определён", 400);
      const point = coordinateFrom(input);
      const radiusM = Math.round(numberValue(input.radius_m ?? 250, "Радиус"));
      if (radiusM < 30 || radiusM > 5000) {
        throw new HttpError("Радиус объекта должен быть от 30 до 5000 метров", 400);
      }
      const { data: objectData, error: objectError } = await adminClient
        .from("objects")
        .select("id")
        .eq("id", objectId)
        .eq("company_id", viewer.companyId)
        .maybeSingle();
      if (objectError) throw objectError;
      if (!asRecord(objectData)) throw new HttpError("Объект не найден", 404);
      const { data, error } = await adminClient
        .from("object_geofences")
        .upsert(
          {
            company_id: viewer.companyId,
            object_id: objectId,
            latitude: point.latitude,
            longitude: point.longitude,
            radius_m: radiusM,
            created_by: viewer.userId,
            updated_at: new Date().toISOString(),
          },
          { onConflict: "company_id,object_id" },
        )
        .select("object_id, latitude, longitude, radius_m, updated_at")
        .single();
      if (error) throw error;
      return json({ ok: true, geofence: asRecord(data) });
    }

    if (action === "route_for_employee") {
      if (!["admin", "developer", "foreman"].includes(viewer.role)) {
        throw new HttpError("Маршрут доступен только руководителю", 403);
      }
      const requestedDate = cleanText(input.work_date, 20);
      const workDate = /^\d{4}-\d{2}-\d{2}$/.test(requestedDate)
        ? requestedDate
        : new Date().toISOString().slice(0, 10);
      const { data: shiftData, error: shiftError } = await adminClient
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
      const shifts = asRecords(shiftData);
      const shiftIds = shifts.map((row) => cleanText(row.id, 80)).filter(Boolean);
      const objectIds = [
        ...new Set(
          shifts.map((row) => cleanText(row.object_id, 80)).filter(Boolean),
        ),
      ];
      let points: DbRow[] = [];
      let geofences: DbRow[] = [];
      if (shiftIds.length > 0) {
        const { data, error } = await adminClient
          .from("employee_work_shift_points")
          .select(
            "id, shift_id, recorded_at, latitude, longitude, accuracy_m, altitude_m, " +
              "speed_mps, heading_deg, is_mock, source",
          )
          .eq("company_id", viewer.companyId)
          .in("shift_id", shiftIds)
          .order("recorded_at", { ascending: true })
          .order("id", { ascending: true });
        if (error) throw error;
        points = asRecords(data);
      }
      if (objectIds.length > 0) {
        const { data, error } = await adminClient
          .from("object_geofences")
          .select("object_id, latitude, longitude, radius_m")
          .eq("company_id", viewer.companyId)
          .in("object_id", objectIds);
        if (error) throw error;
        geofences = asRecords(data);
      }
      return json({
        ok: true,
        employee_id: employee.id,
        work_date: workDate,
        shifts,
        points,
        geofences,
      });
    }

    if (action === "start_shift") {
      const objectId = employee.objectId;
      if (!objectId) {
        throw new HttpError("У сотрудника не определён текущий объект", 400);
      }
      const geofence = await getGeofence(adminClient, viewer, objectId);
      if (!geofence) {
        throw new HttpError(
          "Для объекта не настроена точка начала смены. Обратитесь к руководителю.",
          409,
        );
      }
      const point = coordinateFrom(input);
      if (point.isMock) {
        throw new HttpError("Обнаружена подмена геопозиции. Смена не начата.", 403);
      }
      const permissionScope = cleanText(input.permission_scope, 30);
      const trackingMode = cleanText(input.tracking_mode, 30);
      if (trackingMode === "native_background" && permissionScope !== "always") {
        throw new HttpError(
          "Разрешите доступ к геопозиции «Всегда», чтобы начать смену.",
          422,
        );
      }
      if (!["native_background", "web_foreground"].includes(trackingMode)) {
        throw new HttpError("Неизвестный режим записи маршрута", 400);
      }
      const distanceM = haversineMeters(
        point.latitude,
        point.longitude,
        numberValue(geofence.latitude, "Широта объекта"),
        numberValue(geofence.longitude, "Долгота объекта"),
      );
      const radiusM = numberValue(geofence.radius_m, "Радиус объекта");
      if (distanceM > radiusM + Math.min(point.accuracyM, 100)) {
        throw new HttpError(
          `Вы находитесь вне объекта: примерно ${Math.round(distanceM)} м до контрольной точки.`,
          422,
        );
      }
      const existing = await getActiveShift(adminClient, viewer, employee.id);
      if (existing) {
        return json({ ok: true, active_shift: existing, already_active: true });
      }
      const requestedWorkDate = cleanText(input.work_date, 20);
      const workDate = /^\d{4}-\d{2}-\d{2}$/.test(requestedWorkDate)
        ? requestedWorkDate
        : new Date().toISOString().slice(0, 10);
      const { data: shiftData, error: insertError } = await adminClient
        .from("employee_work_shifts")
        .insert({
          company_id: viewer.companyId,
          employee_id: employee.id,
          task_id: null,
          object_id: objectId,
          work_date: workDate,
          status: "active",
          started_at: point.recordedAt,
          start_latitude: point.latitude,
          start_longitude: point.longitude,
          start_accuracy_m: point.accuracyM,
          start_distance_m: distanceM,
          permission_scope: permissionScope || "unknown",
          tracking_mode: trackingMode,
          route_point_count: 1,
          last_point_at: point.recordedAt,
          started_by: viewer.userId,
        })
        .select(
          "id, employee_id, task_id, object_id, work_date, status, started_at, " +
            "start_latitude, start_longitude, permission_scope, tracking_mode, " +
            "route_point_count, last_point_at",
        )
        .single();
      if (insertError) throw insertError;
      const shift = asRecord(shiftData);
      if (!shift) throw new HttpError("Смена не была создана", 500);
      await savePoint(
        adminClient,
        viewer,
        cleanText(shift.id, 80),
        employee.id,
        point,
        "start",
      );
      return json({ ok: true, active_shift: shift, distance_m: distanceM });
    }

    if (action === "append_route_points") {
      const shift = await getActiveShift(adminClient, viewer, employee.id);
      if (!shift) throw new HttpError("Активная смена не найдена", 409);
      const rawPoints = Array.isArray(input.points) ? input.points.slice(0, 100) : [];
      const points = rawPoints
        .map((value) => asRecord(value))
        .filter((value): value is DbRow => value !== null)
        .map(coordinateFrom)
        .filter((point) => !point.isMock);
      if (points.length === 0) return json({ ok: true, inserted: 0 });
      const shiftId = cleanText(shift.id, 80);
      const { error: pointError } = await adminClient
        .from("employee_work_shift_points")
        .insert(
          points.map((point) => ({
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
          })),
        );
      if (pointError) throw pointError;
      const lastPoint = points[points.length - 1];
      const { error: shiftError } = await adminClient
        .from("employee_work_shifts")
        .update({
          route_point_count:
            numberValue(shift.route_point_count ?? 0, "Количество точек") +
            points.length,
          last_point_at: lastPoint.recordedAt,
          updated_at: new Date().toISOString(),
        })
        .eq("id", shiftId)
        .eq("company_id", viewer.companyId)
        .eq("status", "active");
      if (shiftError) throw shiftError;
      return json({ ok: true, inserted: points.length });
    }

    if (action === "finish_shift") {
      const shift = await getActiveShift(adminClient, viewer, employee.id);
      if (!shift) throw new HttpError("Активная смена не найдена", 409);
      const point = coordinateFrom(input);
      if (point.isMock) {
        throw new HttpError(
          "Обнаружена подмена геопозиции. Завершение смены отклонено.",
          403,
        );
      }
      const shiftId = cleanText(shift.id, 80);
      await savePoint(adminClient, viewer, shiftId, employee.id, point, "finish");
      const { data, error } = await adminClient
        .from("employee_work_shifts")
        .update({
          status: "completed",
          ended_at: point.recordedAt,
          end_latitude: point.latitude,
          end_longitude: point.longitude,
          end_accuracy_m: point.accuracyM,
          route_point_count:
            numberValue(shift.route_point_count ?? 0, "Количество точек") + 1,
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
      const completedShift = asRecord(data);
      if (!completedShift) throw new HttpError("Смена не была завершена", 500);
      return json({ ok: true, completed_shift: completedShift });
    }

    const taskId = cleanText(input.task_id, 80);
    if (!taskId) throw new HttpError("Задача не определена", 400);
    const task = await assignedTask(adminClient, viewer, employee, taskId);

    if (action === "start_task") {
      const shift = await getActiveShift(adminClient, viewer, employee.id);
      if (!shift) {
        throw new HttpError("Сначала начните рабочую смену", 409);
      }
      assertSameObject(task, shift);
      const currentStatus = cleanText(task.status, 80);
      if (currentStatus === "Выполнено") {
        throw new HttpError("Выполненную задачу нельзя начать заново", 409);
      }
      if (currentStatus !== "В работе") {
        const { error } = await adminClient
          .from("tasks")
          .update({ status: "В работе", updated_at: new Date().toISOString() })
          .eq("id", taskId)
          .eq("company_id", viewer.companyId);
        if (error) throw error;
      }
      return json({ ok: true, status: "В работе" });
    }

    if (action === "upload_task_photo") {
      const shift = await getActiveShift(adminClient, viewer, employee.id);
      if (!shift) throw new HttpError("Сначала начните рабочую смену", 409);
      assertSameObject(task, shift);
      const taskStatus = cleanText(task.status, 80);
      if (taskStatus === "Выполнено") {
        throw new HttpError("Выполненная задача закрыта для новых фотографий", 409);
      }
      if (taskStatus !== "В работе") {
        throw new HttpError("Сначала нажмите «Начать выполнение»", 409);
      }
      const stage = cleanText(input.photo_stage, 20);
      if (stage !== "before" && stage !== "after") {
        throw new HttpError("Неизвестный тип фотографии", 400);
      }
      const contentType = cleanText(input.content_type, 80).toLowerCase();
      const extensions: Record<string, string> = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
      };
      const extension = extensions[contentType];
      if (!extension) {
        throw new HttpError("Можно загрузить только JPG, PNG или WEBP", 400);
      }
      const bytes = decodePhoto(cleanText(input.base64, 8_000_000));
      if (bytes.length === 0 || bytes.length > 5 * 1024 * 1024) {
        throw new HttpError("Размер фотографии должен быть не более 5 МБ", 400);
      }
      const storagePath =
        `${taskId}/${stage}/${Date.now()}_${crypto.randomUUID()}.${extension}`;
      const originalName =
        cleanText(input.original_name, 240) || `photo.${extension}`;
      const { error: uploadError } = await adminClient.storage
        .from("task-photos")
        .upload(storagePath, bytes, { contentType, upsert: false });
      if (uploadError) throw uploadError;
      const { data, error } = await adminClient
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
      if (error) {
        await adminClient.storage.from("task-photos").remove([storagePath]);
        throw error;
      }
      return json({ ok: true, photo: asRecord(data) });
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
