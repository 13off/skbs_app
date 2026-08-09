import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import { clean, nameMatches, normalized } from "./shared.ts";

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

type ObjectSummaryRow = { name: string };
type CandidateSummaryRow = { full_name: string };
type ProcurementSummaryRow = {
  id: string;
  title: string;
  status: string;
  object_name: string | null;
};

function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

async function resolveObject({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
}) {
  if (role === "foreman") return assignedObject;
  const { data, error } = await client
    .from("objects")
    .select("name")
    .eq("company_id", companyId)
    .eq("is_active", true)
    .order("name")
    .limit(300);
  if (error) throw error;
  const objects = (data ?? []) as ObjectSummaryRow[];
  const matches = objects.filter((item) => nameMatches(prompt, item.name));
  if (matches.length === 1) return clean(matches[0].name, 180);
  return requestedObject;
}

function readResult({
  title,
  summary,
  highlights = [],
  warnings = [],
  objectName,
  date,
  topic,
  queryMode,
  prompt,
}: {
  title: string;
  summary: string;
  highlights?: string[];
  warnings?: string[];
  objectName: string;
  date: string;
  topic: string;
  queryMode: string;
  prompt: string;
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
    conversation: {
      topic,
      query_mode: queryMode,
      object_name: objectName,
      date,
      prompt,
    },
  };
}

export function operationalQueryIntent(prompt: string): boolean {
  const value = normalized(prompt);
  const employees =
    /(?:сколько|количество|число|кто|состав|перечисли).*(?:сотрудник|работник|люд|человек|бригада)/.test(
      value,
    );
  const tasks =
    /(?:сколько|какие|перечисли|что\s+по).*(?:задач|наряд|работ)/.test(value);
  const candidates =
    /(?:сколько|количество|число|кто|какие|перечисли).*(?:кандидат|соискател)/.test(
      value,
    );
  const procurement =
    /(?:сколько|количество|число|какие|перечисли).*(?:заявк|закуп|снабжен)/.test(
      value,
    );
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

  if (
    /(?:сколько|количество|число|кто|состав|перечисли).*(?:сотрудник|работник|люд|человек|бригада)/.test(
      value,
    )
  ) {
    if (!managerRole(role) && role !== "foreman" && role !== "hr") {
      return { error: "Сводка по сотрудникам недоступна текущей роли", status: 403 };
    }
    const objectName = await resolveObject({
      client,
      companyId,
      role,
      assignedObject,
      requestedObject,
      prompt,
    });
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
        topic: "employees",
        queryMode: wantsNames ? "list" : "count",
        prompt,
      }),
      status: 200,
    };
  }

  if (/(?:сколько|какие|перечисли|что\s+по).*(?:задач|наряд|работ)/.test(value)) {
    if (!managerRole(role) && role !== "foreman") {
      return { error: "Сводка по задачам недоступна текущей роли", status: 403 };
    }
    const objectName = await resolveObject({
      client,
      companyId,
      role,
      assignedObject,
      requestedObject,
      prompt,
    });
    const dateScoped = /(?:сегодня|завтра|послезавтра|вчера|20\d{2}-\d{2}-\d{2}|на\s+\d{1,2}[./]\d{1,2})/.test(
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
        topic: "tasks",
        queryMode: wantsList ? "list" : "count",
        prompt,
      }),
      status: 200,
    };
  }

  if (
    /(?:сколько|количество|число|кто|какие|перечисли).*(?:кандидат|соискател)/.test(
      value,
    )
  ) {
    if (!managerRole(role) && role !== "hr") {
      return { error: "Сводка по кандидатам недоступна текущей роли", status: 403 };
    }
    const wantsList = /(?:кто|какие|перечисли)/.test(value);
    const { data, count, error } = await client
      .from("recruitment_applications")
      .select("full_name", { count: "exact" })
      .eq("company_id", companyId)
      .is("archived_at", null)
      .order("updated_at", { ascending: false })
      .limit(wantsList ? 20 : 1);
    if (error) throw error;
    const rows = (data ?? []) as CandidateSummaryRow[];
    const total = count ?? rows.length;
    const highlights = wantsList ? rows.map((item) => item.full_name) : [];
    const warnings = wantsList && total > highlights.length
      ? [`Показаны первые ${highlights.length} из ${total} кандидатов.`]
      : [];
    return {
      body: readResult({
        title: "Кандидаты",
        summary: `Сейчас в активной воронке ${total} кандидатов.`,
        highlights,
        warnings,
        objectName: requestedObject,
        date,
        topic: "candidates",
        queryMode: wantsList ? "list" : "count",
        prompt,
      }),
      status: 200,
    };
  }

  if (
    /(?:сколько|количество|число|какие|перечисли).*(?:заявк|закуп|снабжен)/.test(
      value,
    )
  ) {
    if (!managerRole(role) && role !== "procurement") {
      return { error: "Сводка по снабжению недоступна текущей роли", status: 403 };
    }
    const objectName = await resolveObject({
      client,
      companyId,
      role,
      assignedObject,
      requestedObject,
      prompt,
    });
    let query = client
      .from("procurement_requests")
      .select("id, title, status, object_name")
      .eq("company_id", companyId)
      .order("updated_at", { ascending: false })
      .limit(1000);
    if (objectName) query = query.eq("object_name", objectName);
    const { data, error } = await query;
    if (error) throw error;
    const active = ((data ?? []) as ProcurementSummaryRow[]).filter((item) => {
      const status = clean(item.status, 40);
      return status !== "delivered" && status !== "canceled";
    });
    const wantsList = /(?:какие|перечисли)/.test(value);
    const highlights = wantsList
      ? active.slice(0, 12).map((item) => item.title)
      : [];
    const warnings = wantsList && active.length > highlights.length
      ? [`Показаны первые ${highlights.length} из ${active.length} заявок.`]
      : [];
    return {
      body: readResult({
        title: "Снабжение",
        summary: `${objectName ? `${objectName}: ` : ""}${active.length} заявок сейчас в работе.`,
        highlights,
        warnings,
        objectName,
        date,
        topic: "procurement",
        queryMode: wantsList ? "list" : "count",
        prompt,
      }),
      status: 200,
    };
  }

  return { error: "Не понял, какую оперативную сводку показать", status: 400 };
}
