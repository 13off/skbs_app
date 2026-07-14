import { clean, dataOrEmpty, dateRu, dateTimeRu, ranked, section } from "./shared.ts";
import { applyPeriod, PeriodFilter } from "./period.ts";
import { SearchResultParts } from "./core_search.ts";

export interface ExtraFlags {
  comments: boolean;
  notifications: boolean;
  files: boolean;
  broad: boolean;
}

export async function searchExtra({
  client,
  companyId,
  objectName,
  tokens,
  period,
  employees,
  matchedEmployee,
  flags,
}: {
  client: any;
  companyId: string;
  objectName: string;
  tokens: string[];
  period: PeriodFilter;
  employees: any[];
  matchedEmployee: any | null;
  flags: ExtraFlags;
}): Promise<SearchResultParts> {
  const sections: string[] = [];
  const highlights: string[] = [];
  const warnings: string[] = [];
  const employeeById = new Map<string, any>(
    employees.map((employee: any) => [String(employee.id), employee]),
  );

  if (flags.comments || flags.broad) {
    let query: any = client
      .from("employee_comments")
      .select("employee_id, comment_text, created_by, created_at")
      .eq("company_id", companyId)
      .order("created_at", { ascending: false })
      .limit(300);
    if (matchedEmployee) query = query.eq("employee_id", matchedEmployee.id);
    const comments = await dataOrEmpty(query, "search employee comments");
    const found = ranked(
      comments,
      tokens,
      (item: any) => [
        employeeById.get(String(item.employee_id))?.fio,
        item.comment_text,
        item.created_by,
        item.created_at,
      ],
      20,
    ).filter((item: any) => employeeById.has(String(item.employee_id)));
    const lines = found.map((item: any) => [
      `• ${dateTimeRu(item.created_at)}`,
      clean(employeeById.get(String(item.employee_id))?.fio, 180) || "Сотрудник",
      clean(item.comment_text, 400),
      clean(item.created_by, 160),
    ].filter(Boolean).join(" • "));
    section(sections, "Комментарии сотрудников", lines);
    if (lines.length > 0) highlights.push(`Комментарии: ${lines.length}`);
  }

  if (flags.notifications || flags.broad) {
    let query: any = client
      .from("app_notifications")
      .select("title, body, actor_name, object_name, entity_type, created_at")
      .eq("company_id", companyId)
      .order("created_at", { ascending: false })
      .limit(300);
    if (objectName) query = query.eq("object_name", objectName);
    const notifications = await dataOrEmpty(query, "search notifications");
    const found = ranked(
      notifications,
      tokens,
      (item: any) => [
        item.title,
        item.body,
        item.actor_name,
        item.object_name,
        item.entity_type,
        item.created_at,
      ],
      20,
    );
    const lines = found.map((item: any) => [
      `• ${dateTimeRu(item.created_at)}`,
      clean(item.title, 180),
      clean(item.body, 400),
      clean(item.object_name, 180),
      clean(item.actor_name, 160),
    ].filter(Boolean).join(" • "));
    section(sections, "Уведомления", lines);
    if (lines.length > 0) highlights.push(`Уведомления: ${lines.length}`);
  }

  if (flags.files || flags.broad) {
    let tasksQuery: any = client
      .from("tasks")
      .select("id, task_date, object_name, axes, work, status")
      .eq("company_id", companyId)
      .order("task_date", { ascending: false })
      .limit(500);
    if (objectName) tasksQuery = tasksQuery.eq("object_name", objectName);
    tasksQuery = applyPeriod(tasksQuery, "task_date", period);
    const tasks = await dataOrEmpty(tasksQuery, "search file tasks");
    const taskById = new Map<string, any>(
      tasks.map((task: any) => [String(task.id), task]),
    );

    let assignedTaskIds: Set<string> | null = null;
    if (matchedEmployee) {
      const assignments = await dataOrEmpty(
        client
          .from("task_assignees")
          .select("task_id")
          .eq("company_id", companyId)
          .eq("employee_id", matchedEmployee.id),
        "search task assignees",
      );
      assignedTaskIds = new Set(
        assignments.map((item: any) => String(item.task_id)),
      );
    }

    const photos = await dataOrEmpty(
      client
        .from("task_photos")
        .select("task_id, original_name, created_at")
        .eq("company_id", companyId)
        .order("created_at", { ascending: false })
        .limit(300),
      "search task files",
    );
    const found = ranked(
      photos,
      tokens,
      (item: any) => {
        const task = taskById.get(String(item.task_id));
        return [
          item.original_name,
          item.created_at,
          task?.task_date,
          task?.work,
          task?.axes,
          task?.object_name,
          task?.status,
          assignedTaskIds?.has(String(item.task_id)) ? matchedEmployee?.fio : "",
        ];
      },
      20,
    ).filter((item: any) => {
      if (!taskById.has(String(item.task_id))) return false;
      if (assignedTaskIds && !assignedTaskIds.has(String(item.task_id))) {
        return false;
      }
      return true;
    });
    const lines = found.map((item: any) => {
      const task = taskById.get(String(item.task_id));
      return [
        `• ${dateTimeRu(item.created_at)}`,
        clean(item.original_name, 240) || "Файл задачи",
        clean(task?.object_name, 180),
        clean(task?.axes, 180),
        clean(task?.work, 260),
        dateRu(task?.task_date),
      ].filter(Boolean).join(" • ");
    });
    section(sections, "Файлы задач", lines);
    if (lines.length > 0) highlights.push(`Файлы задач: ${lines.length}`);
  }

  return { sections, highlights, warnings };
}
