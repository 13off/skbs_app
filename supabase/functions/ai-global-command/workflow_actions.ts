import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import {
  clean,
  nameMatches,
  normalized,
  resultWithAction,
  tokens,
} from "./shared.ts";

type EmployeeRow = { id: string; fio: string; object_name: string };
type TaskRow = {
  id: string;
  work: string;
  axes: string;
  status: string;
  task_date: string;
  object_name: string;
};
type FlightRow = {
  id: string;
  application_id: string;
  departure_at: string;
  status: string;
  arrival_city: string;
  flight_number: string;
};
type CandidateRow = { id: string; full_name: string };
type UserRow = { id: string; full_name: string; is_active: boolean };
type ArchivedEmployeeRow = {
  id: string;
  fio: string;
  position: string;
  object_name: string;
};

function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

function hrRole(role: string) {
  return managerRole(role) || role === "hr";
}

function words(value: string): string[] {
  return tokens(value).filter((item) => item.length >= 3);
}

function score(prompt: string, title: string): number {
  const a = words(prompt);
  const b = words(title);
  if (b.length === 0) return 0;
  let hit = 0;
  for (const item of b) {
    if (
      a.some(
        (token) =>
          token === item ||
          (Math.min(token.length, item.length) >= 5 &&
            (token.startsWith(item) || item.startsWith(token))),
      )
    ) {
      hit++;
    }
  }
  return hit / b.length;
}

function uniqueBest<T>(
  rows: T[],
  scorer: (row: T) => number,
  minimum = 0.45,
): T | null {
  const ranked = rows
    .map((row) => ({ row, score: scorer(row) }))
    .filter((item) => item.score >= minimum)
    .sort((a, b) => b.score - a.score);
  if (ranked.length === 0) return rows.length === 1 ? rows[0] : null;
  if (
    ranked.length > 1 &&
    Math.abs(ranked[0].score - ranked[1].score) < 0.0001
  ) {
    return null;
  }
  return ranked[0].row;
}

async function currentEmployee(
  client: SupabaseClient,
  companyId: string,
  userId: string,
): Promise<EmployeeRow | null> {
  const { data: membership, error: membershipError } = await client
    .from("company_memberships")
    .select("person_id")
    .eq("company_id", companyId)
    .eq("user_id", userId)
    .eq("is_active", true)
    .maybeSingle();
  if (membershipError) throw membershipError;

  const personId = clean(membership?.person_id, 80);
  if (personId) {
    const { data, error } = await client
      .from("employees")
      .select("id, fio, object_name")
      .eq("company_id", companyId)
      .eq("person_id", personId)
      .eq("is_active", true)
      .is("archived_at", null)
      .maybeSingle();
    if (error) throw error;
    if (data) return data as EmployeeRow;
  }

  const { data: link, error: linkError } = await client
    .from("employee_account_links")
    .select("employee_id")
    .eq("company_id", companyId)
    .eq("user_id", userId)
    .maybeSingle();
  if (linkError) throw linkError;
  const employeeId = clean(link?.employee_id, 80);
  if (!employeeId) return null;

  const { data, error } = await client
    .from("employees")
    .select("id, fio, object_name")
    .eq("id", employeeId)
    .eq("company_id", companyId)
    .eq("is_active", true)
    .is("archived_at", null)
    .maybeSingle();
  if (error) throw error;
  return data ? (data as EmployeeRow) : null;
}

export function employeeWorkflowIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:начн|начни|заверш|закончи).*(?:рабоч|смен|день)|(?:начн|начни).*(?:задач)|(?:добав|прикреп).*(?:фото).*(?:задач)|(?:фото\s+(?:до|после))/.test(
    value,
  );
}

export async function buildEmployeeWorkflow({
  client,
  companyId,
  role,
  userId,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  userId: string;
  prompt: string;
  date: string;
}) {
  if (role !== "employee") {
    return {
      error: "Эта команда предназначена для личного кабинета сотрудника",
      status: 403,
    };
  }

  const employee = await currentEmployee(client, companyId, userId);
  if (!employee) {
    return { error: "Не удалось связать аккаунт с сотрудником", status: 400 };
  }
  const value = normalized(prompt);

  if (/(?:начн|начни).*(?:рабоч|смен|день)/.test(value)) {
    return {
      body: resultWithAction({
        title: "Начало рабочего дня",
        summary: `Начать рабочий день: ${employee.fio}.`,
        highlights: [employee.fio, employee.object_name],
        warnings: ["Для старта потребуется доступ к геолокации."],
        objectName: employee.object_name,
        date,
        action: {
          id: crypto.randomUUID(),
          type: "employee_workday",
          title: "Начать рабочий день",
          button_label: "Проверить старт",
          confirmation_required: true,
          payload: {
            operation: "start",
            employee_id: employee.id,
            employee_name: employee.fio,
          },
        },
      }),
      status: 200,
    };
  }

  if (/(?:заверш|закончи).*(?:рабоч|смен|день)/.test(value)) {
    return {
      body: resultWithAction({
        title: "Завершение рабочего дня",
        summary: `Завершить рабочий день: ${employee.fio}.`,
        highlights: [employee.fio],
        warnings: ["После завершения продолжить этот рабочий день нельзя."],
        objectName: employee.object_name,
        date,
        action: {
          id: crypto.randomUUID(),
          type: "employee_workday",
          title: "Завершить рабочий день",
          button_label: "Проверить завершение",
          confirmation_required: true,
          payload: {
            operation: "finish",
            employee_id: employee.id,
            employee_name: employee.fio,
          },
        },
      }),
      status: 200,
    };
  }

  const { data: assigneeRows, error: assigneeError } = await client
    .from("task_assignees")
    .select("task_id")
    .eq("company_id", companyId)
    .eq("employee_id", employee.id)
    .is("removed_at", null);
  if (assigneeError) throw assigneeError;

  const taskIds = (assigneeRows ?? [])
    .map((item) => clean(item.task_id, 80))
    .filter(Boolean);
  if (taskIds.length === 0) {
    return { error: "У сотрудника нет назначенных задач", status: 400 };
  }

  const { data: taskRows, error: taskError } = await client
    .from("tasks")
    .select("id, work, axes, status, task_date, object_name")
    .in("id", taskIds)
    .is("deleted_at", null)
    .neq("status", "Выполнено")
    .order("task_date", { ascending: false })
    .limit(100);
  if (taskError) throw taskError;

  const tasks = (taskRows ?? []) as TaskRow[];
  const task = uniqueBest(
    tasks,
    (item) => Math.max(score(prompt, item.work), score(prompt, item.axes)),
    0.35,
  );
  if (!task) {
    return { error: "Не смог однозначно определить задачу", status: 409 };
  }

  const photoStage = /(?:фото\s+после|после.*фото)/.test(value)
    ? "after"
    : /(?:фото\s+до|до.*фото)/.test(value)
      ? "before"
      : "";
  const operation = photoStage ? `photo_${photoStage}` : "start_task";

  return {
    body: resultWithAction({
      title: photoStage ? "Фото к задаче" : "Начало задачи",
      summary: photoStage
        ? `Добавить фото ${photoStage === "before" ? "до" : "после"}: ${task.work}.`
        : `Начать выполнение: ${task.work}.`,
      highlights: [task.work, task.axes, task.object_name].filter(Boolean),
      warnings: photoStage
        ? ["После подтверждения откроется штатный выбор фото."]
        : [],
      objectName: task.object_name,
      date,
      action: {
        id: crypto.randomUUID(),
        type: "employee_task_action",
        title: photoStage ? "Добавить фото к задаче" : "Начать выполнение задачи",
        button_label: photoStage ? "Выбрать фото" : "Проверить начало",
        confirmation_required: true,
        payload: {
          operation,
          employee_id: employee.id,
          employee_name: employee.fio,
          task_id: task.id,
          task_title: task.work,
          photo_stage: photoStage,
        },
      },
    }),
    status: 200,
  };
}

export function flightWorkflowIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:напомн).*(?:вылет|рейс)|(?:прибыл|прилетел|вылетел|регистрац|отмен).*(?:кандидат|сотрудник|рейс|вылет)?/.test(
    value,
  );
}

function flightStatus(prompt: string): string | null {
  const value = normalized(prompt);
  if (/(?:прибыл|прилетел)/.test(value)) return "arrived";
  if (/(?:вылетел|улетел)/.test(value)) return "departed";
  if (/регистрац/.test(value)) return "checked_in";
  if (/отмен/.test(value)) return "cancelled";
  return null;
}

export async function buildFlightWorkflow({
  client,
  companyId,
  role,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  prompt: string;
  date: string;
}) {
  if (!hrRole(role)) {
    return { error: "Управление вылетами недоступно текущей роли", status: 403 };
  }

  const { data: flightsRaw, error: flightError } = await client
    .from("recruitment_flights")
    .select(
      "id, application_id, departure_at, status, arrival_city, flight_number",
    )
    .eq("company_id", companyId)
    .order("departure_at", { ascending: true })
    .limit(300);
  if (flightError) throw flightError;

  const flights = (flightsRaw ?? []) as FlightRow[];
  const ids = [
    ...new Set(flights.map((item) => item.application_id).filter(Boolean)),
  ];
  const candidateResult = ids.length === 0
    ? { data: [] as unknown[], error: null }
    : await client
      .from("recruitment_applications")
      .select("id, full_name")
      .in("id", ids);
  if (candidateResult.error) throw candidateResult.error;

  const candidates = (candidateResult.data ?? []) as CandidateRow[];
  const nameById = new Map(
    candidates.map((item) => [item.id, item.full_name]),
  );
  const matching = flights.filter((flight) => {
    const name = nameById.get(flight.application_id) ?? "";
    return nameMatches(prompt, name);
  });
  if (matching.length === 0) {
    return { error: "Не нашёл вылет сотрудника по имени", status: 400 };
  }
  if (matching.length > 1) {
    return {
      error: "Нашёл несколько вылетов этого человека. Уточни рейс или дату.",
      status: 409,
    };
  }

  const flight = matching[0];
  const name = nameById.get(flight.application_id) ?? "Сотрудник";
  const reminder = /напомн/.test(normalized(prompt));
  const status = reminder ? "" : flightStatus(prompt);
  if (!reminder && !status) {
    return { error: "Не понял новый статус вылета", status: 400 };
  }

  return {
    body: resultWithAction({
      title: reminder ? "Напоминание о вылете" : "Статус вылета",
      summary: reminder
        ? `Отправить ${name} напоминание о вылете.`
        : `${name}: ${flight.status} → ${status}.`,
      highlights: [name, flight.arrival_city, flight.flight_number].filter(
        Boolean,
      ),
      warnings: [
        reminder
          ? "Напоминание отправится только после подтверждения."
          : "Статус изменится только после подтверждения.",
      ],
      date,
      action: {
        id: crypto.randomUUID(),
        type: "manage_flight",
        title: reminder ? "Отправить напоминание" : "Изменить статус вылета",
        button_label: "Проверить действие",
        confirmation_required: true,
        payload: {
          operation: reminder ? "remind" : "status",
          flight_id: flight.id,
          application_id: flight.application_id,
          candidate_name: name,
          current_status: flight.status,
          new_status: status,
        },
      },
    }),
    status: 200,
  };
}

export function chatMessageIntent(prompt: string): boolean {
  const value = normalized(prompt);
  return /(?:напиши|отправь).*(?:сообщен|в\s+общий\s+чат|в\s+чат)/.test(
    value,
  );
}

function messageBody(prompt: string): string {
  const explicit = prompt.match(/(?:сообщение|чат)\s*[:\-]?\s*(.+)$/i);
  if (explicit) return clean(explicit[1], 4000);
  const direct = prompt.match(
    /(?:напиши|отправь)\s+.+?\s*[:\-]\s*(.+)$/i,
  );
  return clean(direct?.[1], 4000);
}

export async function buildChatMessage({
  client,
  companyId,
  role,
  userId,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  userId: string;
  prompt: string;
  date: string;
}) {
  if (role === "employee") {
    return {
      error: "Корпоративный чат недоступен текущей роли",
      status: 403,
    };
  }

  const body = messageBody(prompt);
  if (!body) {
    return {
      error: "Не понял текст сообщения. Скажи его после слова сообщение.",
      status: 400,
    };
  }

  const general = /(?:в\s+общий\s+чат|в\s+общий)/.test(normalized(prompt));
  let peerUserId = "";
  let peerName = "Общий чат";

  if (!general) {
    const { data: memberships, error: membershipError } = await client
      .from("company_memberships")
      .select("user_id, role, is_active")
      .eq("company_id", companyId)
      .eq("is_active", true);
    if (membershipError) throw membershipError;

    const ids = (memberships ?? [])
      .map((item) => clean(item.user_id, 80))
      .filter((id) => id && id !== userId);
    const userResult = ids.length === 0
      ? { data: [] as unknown[], error: null }
      : await client
        .from("user_profiles")
        .select("id, full_name, is_active")
        .in("id", ids)
        .eq("is_active", true);
    if (userResult.error) throw userResult.error;

    const users = (userResult.data ?? []) as UserRow[];
    const matches = users.filter((user) =>
      nameMatches(prompt, user.full_name)
    );
    if (matches.length === 0) {
      return { error: "Не нашёл получателя сообщения", status: 400 };
    }
    if (matches.length > 1) {
      return {
        error: `Нашёл несколько получателей: ${
          matches.slice(0, 4).map((x) => x.full_name).join(", ")
        }. Уточни имя.`,
        status: 409,
      };
    }
    peerUserId = matches[0].id;
    peerName = matches[0].full_name;
  }

  return {
    body: resultWithAction({
      title: "Сообщение подготовлено",
      summary: `${general ? "Общий чат" : peerName}: ${body}`,
      highlights: [general ? "Общий чат" : peerName, body],
      warnings: ["Сообщение отправится только после подтверждения."],
      date,
      action: {
        id: crypto.randomUUID(),
        type: "send_company_chat_message",
        title: "Отправить сообщение",
        button_label: "Проверить сообщение",
        confirmation_required: true,
        payload: {
          channel_kind: general ? "general" : "direct",
          peer_user_id: peerUserId,
          peer_name: peerName,
          body,
        },
      },
    }),
    status: 200,
  };
}

export function archiveRestoreIntent(prompt: string): boolean {
  return /(?:восстанов).*(?:сотрудник|архив)|(?:сотрудник).*(?:из\s+архив|восстанов)/.test(
    normalized(prompt),
  );
}

export async function buildArchiveRestore({
  client,
  companyId,
  role,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  prompt: string;
  date: string;
}) {
  if (!managerRole(role)) {
    return {
      error: "Архив сотрудников доступен только руководителю",
      status: 403,
    };
  }

  const { data, error } = await client
    .from("employees")
    .select("id, fio, position, object_name")
    .eq("company_id", companyId)
    .not("archived_at", "is", null)
    .order("fio")
    .limit(500);
  if (error) throw error;

  const archived = (data ?? []) as ArchivedEmployeeRow[];
  const matches = archived.filter((employee) =>
    nameMatches(prompt, employee.fio)
  );
  if (matches.length === 0) {
    return { error: "Не нашёл сотрудника в архиве", status: 400 };
  }
  if (matches.length > 1) {
    return {
      error: `Нашёл несколько сотрудников: ${
        matches.slice(0, 4).map((x) => x.fio).join(", ")
      }. Уточни ФИО.`,
      status: 409,
    };
  }

  const employee = matches[0];
  return {
    body: resultWithAction({
      title: "Восстановление сотрудника",
      summary: `Восстановить ${employee.fio} из архива.`,
      highlights: [
        employee.fio,
        employee.position,
        employee.object_name,
      ].filter(Boolean),
      warnings: ["Окончательное удаление голосом недоступно."],
      date,
      action: {
        id: crypto.randomUUID(),
        type: "restore_archive_item",
        title: "Восстановить сотрудника",
        button_label: "Проверить восстановление",
        confirmation_required: true,
        payload: {
          entity_type: "employee",
          employee_id: employee.id,
          employee_name: employee.fio,
        },
      },
    }),
    status: 200,
  };
}
