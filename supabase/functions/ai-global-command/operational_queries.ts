import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import { clean, normalized } from "./shared.ts";

type EmployeeSummaryRow = {
  fio: string;
  position: string;
  object_name: string;
};

type TaskSummaryRow = {
  work: string;
  axes: string;
  status: string;
  task_date: string;
  object_name: string;
};

function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

function scopedObject({
  role,
  assignedObject,
  requestedObject,
}: {
  role: string;
  assignedObject: string;
  requestedObject: string;
}) {
  return role === "foreman" ? assignedObject : requestedObject;
}

function readResult({
  title,
  summary,
  highlights = [],
  warnings = [],
  objectName,
  date,
}: {
  title: string;
  summary: string;
  highlights?: string[];
  warnings?: string[];
  objectName: string;
  date: string;
}) {
  return {
    ok: true,
    mode: "global_voice",
    title,
    summary,
    highlights,
    warnings,
    next_steps: [],
    scope: {
      object_name: objectName || "Все доступные объекты",
      date,
    },
    preliminary: false,
    ai_used: false,
    action: null,
  };
}

export function operationalQueryIntent(prompt: string): boolean {
  const value = normalized(prompt);
  const employees =
    /(?:сколько|количество|число|кто|состав).*(?:сотрудник|работник|люд|человек|бригада)/.test(
      value,
    );
  const tasks =
    /(?:сколько|какие|перечисли|что\s+по).*(?:задач|наряд|работ)/.test(value);
  const candidates =
    /(?:сколько|количество|число).*(?:кандидат|соискател)/.test(value);
  const procurement =
    /(?:сколько|количество|число).*(?:заявк|закуп|снабжен)/.test(value);
  return employees || tasks || candidates || procurement;
}

export async function buildOperationalQuery({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
  date,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
  date: string;
}) {
  const value = normalized(prompt);
  const objectName = scopedObject({ role, assignedObject, requestedObject });

  if (
    /(?:сколько|количество|число|кто|состав).*(?:сотрудник|работник|люд|человек|бригада)/.test(
      value,
    )
  ) {
    if (!managerRole(role) && role !== "foreman" && role !== "hr") {
      return { error: "Сводка по сотрудникам недоступна текущей роли", status: 403 };
    }

    let query = client
      .from("employees")
      .select("fio, position, object_name")
      .eq("company_id", companyId)
      .eq("is_active", true)
      .is("archived_at", null)
      .order("fio")
      .limit(300);
    if (objectName) query = query.eq("object_name", objectName);
    const { data, error } = await query;
    if (error) throw error;
    const rows = (data ?? []) as EmployeeSummaryRow[];

    const wantsNames = /(?:кто|состав|перечисли)/.test(value);
    const highlights = wantsNames
      ? rows
        .slice(0, 20)
        .map((item) => `${item.fio}${item.position ? ` — ${item.position}` : ""}`)
      : [];
    const hidden = wantsNames && rows.length > highlights.length
      ? [`Показаны первые ${highlights.length} из ${rows.length}.`]
      : [];

    return {
      body: readResult({
        title: "Сотрудники",
        summary: `${objectName ? `${objectName}: ` : ""}${rows.length} активных сотрудников.`,
        highlights,
        warnings: hidden,
        objectName,
        date,
      }),
      status: 200,
    };
  }

  if (/(?:сколько|какие|перечисли|что\s+по).*(?:задач|наряд|работ)/.test(value)) {
    if (!managerRole(role) && role !== "foreman") {
      return { error: "Сводка по задачам недоступна текущей роли", status: 403 };
    }

    const dateScoped = /(?:сегодня|завтра|послезавтра|вчера|на\s+\d{1,2}[./]\d{1,2})/.test(
      value,
    );
    let query = client
      .from("tasks")
      .select("work, axes, status, task_date, object_name")
      .eq("company_id", companyId)
      .is("deleted_at", null)
      .neq("status", "Выполнено")
      .order("task_date", { ascending: true })
      .limit(300);
    if (objectName) query = query.eq("object_name", objectName);
    if (dateScoped) query = query.eq("task_date", date);
    const { data, error } = await query;
    if (error) throw error;
    const rows = (data ?? []) as TaskSummaryRow[];

    const wantsList = /(?:какие|перечисли|что\s+по)/.test(value);
    const highlights = wantsList
      ? rows.slice(0, 12).map((item) => {
        const axes = clean(item.axes, 100);
        return `${item.task_date} · ${item.work}${axes ? ` · оси ${axes}` : ""}`;
      })
      : [];
    const warnings = wantsList && rows.length > highlights.length
      ? [`Показаны первые ${highlights.length} из ${rows.length} открытых задач.`]
      : [];

    return {
      body: readResult({
        title: dateScoped ? "Задачи на выбранный день" : "Открытые задачи",
        summary: `${objectName ? `${objectName}: ` : ""}${rows.length} открытых задач${dateScoped ? ` на ${date}` : ""}.`,
        highlights,
        warnings,
        objectName,
        date,
      }),
      status: 200,
    };
  }

  if (/(?:сколько|количество|число).*(?:кандидат|соискател)/.test(value)) {
    if (!managerRole(role) && role !== "hr") {
      return { error: "Сводка по кандидатам недоступна текущей роли", status: 403 };
    }
    const { count, error } = await client
      .from("recruitment_applications")
      .select("id", { count: "exact", head: true })
      .eq("company_id", companyId)
      .is("archived_at", null);
    if (error) throw error;
    const total = count ?? 0;
    return {
      body: readResult({
        title: "Кандидаты",
        summary: `Сейчас в активной воронке ${total} кандидатов.`,
        objectName,
        date,
      }),
      status: 200,
    };
  }

  if (/(?:сколько|количество|число).*(?:заявк|закуп|снабжен)/.test(value)) {
    if (!managerRole(role) && role !== "procurement") {
      return { error: "Сводка по снабжению недоступна текущей роли", status: 403 };
    }
    let query = client
      .from("procurement_requests")
      .select("id, status, object_name")
      .eq("company_id", companyId)
      .limit(1000);
    if (objectName) query = query.eq("object_name", objectName);
    const { data, error } = await query;
    if (error) throw error;
    const active = (data ?? []).filter((item) => {
      const status = clean(item.status, 40);
      return status !== "delivered" && status !== "canceled";
    });
    return {
      body: readResult({
        title: "Снабжение",
        summary: `${objectName ? `${objectName}: ` : ""}${active.length} заявок сейчас в работе.`,
        objectName,
        date,
      }),
      status: 200,
    };
  }

  return { error: "Не понял, какую оперативную сводку показать", status: 400 };
}
