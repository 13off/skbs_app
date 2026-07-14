import { clean, dataOrEmpty, dateRu, num, ranked, section } from "./shared.ts";
import { applyPeriod, PeriodFilter } from "./period.ts";

export interface SearchFlags {
  employees: boolean;
  objects: boolean;
  tasks: boolean;
  attendance: boolean;
  payments: boolean;
  receipts: boolean;
  users: boolean;
  company: boolean;
  invitations: boolean;
  broad: boolean;
}

export interface SearchResultParts {
  sections: string[];
  highlights: string[];
  warnings: string[];
}

export async function searchCore({
  client,
  companyId,
  objectName,
  normalized,
  tokens,
  period,
  employees,
  objects,
  flags,
}: {
  client: any;
  companyId: string;
  objectName: string;
  normalized: string;
  tokens: string[];
  period: PeriodFilter;
  employees: any[];
  objects: any[];
  flags: SearchFlags;
}): Promise<SearchResultParts> {
  const sections: string[] = [];
  const highlights: string[] = [];
  const warnings: string[] = [];

  if (flags.employees || flags.broad) {
    const found = ranked(
      employees,
      tokens,
      (employee: any) => [
        employee.fio,
        employee.position,
        employee.object_name,
        employee.comment,
        employee.is_active && !employee.archived_at ? "активный" : "архивный",
      ],
      20,
    ).filter((employee: any) => {
      if (/архивн|уволен/.test(normalized)) {
        return Boolean(employee.archived_at) || employee.is_active !== true;
      }
      if (/активн/.test(normalized)) {
        return employee.is_active === true && !employee.archived_at;
      }
      return true;
    });
    const lines = found.map((employee: any) => [
      `• ${clean(employee.fio, 180)}`,
      clean(employee.position, 120),
      clean(employee.object_name, 180),
      employee.is_active && !employee.archived_at ? "активен" : "архив",
      clean(employee.comment, 220),
    ].filter(Boolean).join(" • "));
    section(sections, "Сотрудники", lines);
    if (lines.length > 0) highlights.push(`Сотрудники: ${lines.length}`);
  }

  if (flags.objects || flags.broad) {
    const found = ranked(
      objects,
      tokens,
      (object: any) => [
        object.name,
        object.address,
        object.comment,
        object.is_active ? "активный" : "архивный",
      ],
      20,
    );
    const lines = found.map((object: any) => [
      `• ${clean(object.name, 180)}`,
      clean(object.address, 240),
      object.is_active ? "активен" : "архив",
      clean(object.comment, 220),
    ].filter(Boolean).join(" • "));
    section(sections, "Объекты", lines);
    if (lines.length > 0) highlights.push(`Объекты: ${lines.length}`);
  }

  let tasksQuery: any = client
    .from("tasks")
    .select("task_date, object_name, axes, work, status, created_by, not_done_comment")
    .eq("company_id", companyId)
    .order("task_date", { ascending: false })
    .limit(500);
  if (objectName) tasksQuery = tasksQuery.eq("object_name", objectName);
  tasksQuery = applyPeriod(tasksQuery, "task_date", period);

  let attendanceQuery: any = client
    .from("attendance")
    .select("employee_id, work_date, object_name, shifts, hours, status, comment, marked_by")
    .eq("company_id", companyId)
    .order("work_date", { ascending: false })
    .limit(500);
  if (objectName) attendanceQuery = attendanceQuery.eq("object_name", objectName);
  attendanceQuery = applyPeriod(attendanceQuery, "work_date", period);

  const [tasks, attendance] = await Promise.all([
    flags.tasks || flags.broad
      ? dataOrEmpty(tasksQuery, "search tasks")
      : Promise.resolve([]),
    flags.attendance || flags.broad
      ? dataOrEmpty(attendanceQuery, "search attendance")
      : Promise.resolve([]),
  ]);

  if (flags.tasks || flags.broad) {
    const found = ranked(
      tasks,
      tokens,
      (task: any) => [
        task.task_date,
        task.object_name,
        task.axes,
        task.work,
        task.status,
        task.created_by,
        task.not_done_comment,
      ],
      20,
    ).filter((task: any) => {
      const notDone = /невыполн|не выполн|в работе|остал|просроч/.test(normalized);
      const done = /выполнен/.test(normalized) && !notDone;
      if (notDone) return task.status !== "Выполнено";
      if (done) return task.status === "Выполнено";
      return true;
    });
    const lines = found.map((task: any) => [
      `• ${dateRu(task.task_date)}`,
      clean(task.object_name, 180),
      clean(task.status, 100),
      clean(task.axes, 180),
      clean(task.work, 300),
      clean(task.not_done_comment, 240),
    ].filter(Boolean).join(" • "));
    section(sections, "Задачи", lines);
    if (lines.length > 0) highlights.push(`Задачи: ${lines.length}`);
  }

  if (flags.attendance || flags.broad) {
    const employeeById = new Map<string, any>(
      employees.map((employee: any) => [String(employee.id), employee]),
    );
    const found = ranked(
      attendance,
      tokens,
      (row: any) => {
        const employee = employeeById.get(String(row.employee_id));
        return [
          employee?.fio,
          employee?.position,
          row.work_date,
          row.object_name,
          row.status,
          row.comment,
          row.marked_by,
          row.shifts,
          row.hours,
        ];
      },
      25,
    );
    const lines = found.map((row: any) => {
      const employee = employeeById.get(String(row.employee_id));
      return [
        `• ${dateRu(row.work_date)}`,
        clean(employee?.fio, 180) || "Сотрудник",
        clean(row.object_name, 180),
        `${num(row.shifts).toFixed(1)} смен`,
        num(row.hours) > 0 ? `${num(row.hours).toFixed(1)} ч` : "",
        clean(row.status, 100),
        clean(row.comment, 220),
      ].filter(Boolean).join(" • ");
    });
    section(sections, "Табель", lines);
    if (lines.length > 0) highlights.push(`Строки табеля: ${lines.length}`);
  }

  if (/телефон|номер телефона|ставк|паспорт/.test(normalized)) {
    warnings.push(
      "Эти данные не выводятся в общем поиске. Открой карточку сотрудника с соответствующими правами.",
    );
  }

  return { sections, highlights, warnings };
}
