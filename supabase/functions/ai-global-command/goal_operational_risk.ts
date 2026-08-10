import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import type { GlobalVoiceConversationContext } from "./conversation_context.ts";
import {
  type CandidateAssessment,
  loadCandidateReadiness,
} from "./goal_candidate_readiness.ts";
import {
  type BuilderResult,
  dateIsOnOrBefore,
  managerRole,
  operationalRole,
  readOnlyGoalBody,
  resolveGoalObjectScope,
} from "./goal_planner_shared.ts";
import { clean, normalized } from "./shared.ts";

type EmployeeRow = {
  id: string;
  fio: string;
  object_id: string | null;
  object_name: string | null;
  position: string | null;
};

type TaskRow = {
  id: string;
  task_date: string;
  object_id: string | null;
  object_name: string | null;
  work: string;
  axes: string | null;
  status: string;
};

type ProcurementRow = {
  id: string;
  title: string;
  object_id: string | null;
  object_name: string | null;
  status: string;
  priority: string;
  needed_by: string | null;
};

type RiskCategory = "attendance" | "tasks" | "procurement" | "hr";
type OperationalMode = "all" | RiskCategory;

type RiskIssue = {
  category: RiskCategory;
  severity: number;
  objectName: string;
  label: string;
};

function operationalMode(prompt: string): OperationalMode {
  const value = normalized(prompt);
  if (/(?:только|лишь).*(?:табел|выход|сотрудник|люд)/.test(value)) return "attendance";
  if (/(?:только|лишь).*(?:задач)/.test(value)) return "tasks";
  if (/(?:только|лишь).*(?:снабжен|закуп|заявк|поставк)/.test(value)) return "procurement";
  if (/(?:только|лишь).*(?:hr|кадр|кандидат|вылет)/.test(value)) return "hr";
  return "all";
}

function categoryEnabled(mode: OperationalMode, category: RiskCategory): boolean {
  return mode === "all" || mode === category;
}

function taskIssue(row: TaskRow, baseDate: string): RiskIssue {
  const overdue = clean(row.task_date, 10) < baseDate;
  const axes = clean(row.axes, 120);
  return {
    category: "tasks",
    severity: overdue ? 4 : 2,
    objectName: clean(row.object_name, 180),
    label: `[Задача] ${clean(row.work, 220)}${axes ? ` • оси ${axes}` : ""} • срок ${clean(row.task_date, 10)} • ${clean(row.status, 60)}`,
  };
}

function procurementIssue(row: ProcurementRow, baseDate: string): RiskIssue {
  const due = clean(row.needed_by, 10);
  const overdue = due.length > 0 && due < baseDate;
  const urgent = clean(row.priority, 30) === "urgent";
  const severity = overdue && urgent ? 6 : overdue ? 5 : urgent ? 4 : 3;
  return {
    category: "procurement",
    severity,
    objectName: clean(row.object_name, 180),
    label: `[Снабжение] ${clean(row.title, 220)} • нужно ${due || "без срока"} • ${clean(row.priority, 30)} • ${clean(row.status, 60)}`,
  };
}

function attendanceIssue(row: EmployeeRow, date: string): RiskIssue {
  return {
    category: "attendance",
    severity: 2,
    objectName: clean(row.object_name, 180),
    label: `[Табель] ${clean(row.fio, 180)}${clean(row.position, 100) ? ` • ${clean(row.position, 100)}` : ""} • нет положительной отметки за ${date}`,
  };
}

function candidateIssue(item: CandidateAssessment, objectName: string): RiskIssue {
  const route = item.flight
    ? `${clean(item.flight.origin, 80)} → ${clean(item.flight.destination, 80)}`
    : "без рейса";
  return {
    category: "hr",
    severity: Math.max(2, item.severity),
    objectName,
    label: `[HR] ${clean(item.row.full_name, 180)} • ${route} • ${item.issueTexts.join("; ")}`,
  };
}

function categoryCounts(issues: RiskIssue[]): Record<RiskCategory, number> {
  return {
    attendance: issues.filter((item) => item.category === "attendance").length,
    tasks: issues.filter((item) => item.category === "tasks").length,
    procurement: issues.filter((item) => item.category === "procurement").length,
    hr: issues.filter((item) => item.category === "hr").length,
  };
}

function objectSummary(issues: RiskIssue[]): string[] {
  const buckets = new Map<string, RiskIssue[]>();
  for (const issue of issues) {
    const name = issue.objectName || "Без объекта";
    const rows = buckets.get(name) ?? [];
    rows.push(issue);
    buckets.set(name, rows);
  }
  return [...buckets.entries()]
    .map(([name, rows]) => {
      const counts = categoryCounts(rows);
      const score = rows.reduce((sum, row) => sum + row.severity, 0);
      return {
        score,
        text: `${name}: риск ${score} • табель ${counts.attendance} • задачи ${counts.tasks} • снабжение ${counts.procurement} • HR ${counts.hr}`,
      };
    })
    .sort((left, right) => right.score - left.score)
    .slice(0, 6)
    .map((item) => item.text);
}

export async function buildOperationalRiskGoal({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
  date,
  baseDate,
  conversationContext,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
  date: string;
  baseDate: string;
  conversationContext: GlobalVoiceConversationContext;
}): Promise<BuilderResult> {
  if (!operationalRole(role)) {
    return { error: "Операционная диагностика объекта недоступна текущей роли", status: 403 };
  }

  const inherited = conversationContext.topic === "goal_operational_risk";
  const effectiveDate = inherited && conversationContext.date
    ? conversationContext.date
    : date;
  const sourcePrompt = inherited && conversationContext.prompt
    ? `${conversationContext.prompt}. ${prompt}`
    : prompt;
  const objectScope = await resolveGoalObjectScope({
    client,
    companyId,
    role,
    assignedObject,
    requestedObject: requestedObject || (inherited ? conversationContext.objectName : ""),
    prompt: sourcePrompt,
  });
  if (objectScope && "error" in objectScope) return objectScope;
  const mode = operationalMode(prompt);
  const issues: RiskIssue[] = [];
  const checks: string[] = [];

  if (categoryEnabled(mode, "attendance") && dateIsOnOrBefore(effectiveDate, baseDate)) {
    checks.push("attendance_marks");
    let employeesQuery = client
      .from("employees")
      .select("id, fio, object_id, object_name, position")
      .eq("company_id", companyId)
      .eq("is_active", true)
      .is("archived_at", null)
      .order("fio")
      .limit(1000);
    let attendanceQuery = client
      .from("attendance")
      .select("employee_id, shifts")
      .eq("company_id", companyId)
      .eq("work_date", effectiveDate)
      .is("deleted_at", null)
      .limit(3000);
    if (objectScope) {
      employeesQuery = employeesQuery.eq("object_id", objectScope.id);
      attendanceQuery = attendanceQuery.eq("object_id", objectScope.id);
    }
    const [employeesResult, attendanceResult] = await Promise.all([
      employeesQuery,
      attendanceQuery,
    ]);
    if (employeesResult.error) throw employeesResult.error;
    if (attendanceResult.error) throw attendanceResult.error;
    const positive = new Set<string>();
    for (const raw of attendanceResult.data ?? []) {
      const id = clean((raw as any).employee_id, 80);
      const shifts = Number((raw as any).shifts ?? 0);
      if (id && Number.isFinite(shifts) && shifts > 0) positive.add(id);
    }
    for (const employee of (employeesResult.data ?? []) as EmployeeRow[]) {
      if (!positive.has(employee.id)) issues.push(attendanceIssue(employee, effectiveDate));
    }
  }

  if (categoryEnabled(mode, "tasks")) {
    checks.push("open_tasks_due_by_date");
    let query = client
      .from("tasks")
      .select("id, task_date, object_id, object_name, work, axes, status")
      .eq("company_id", companyId)
      .is("deleted_at", null)
      .eq("is_draft", false)
      .neq("status", "Выполнено")
      .lte("task_date", effectiveDate)
      .order("task_date", { ascending: true })
      .limit(1000);
    if (objectScope) query = query.eq("object_id", objectScope.id);
    const { data, error } = await query;
    if (error) throw error;
    for (const row of (data ?? []) as TaskRow[]) issues.push(taskIssue(row, baseDate));
  }

  if (categoryEnabled(mode, "procurement")) {
    checks.push("procurement_due_by_date");
    let query = client
      .from("procurement_requests")
      .select("id, title, object_id, object_name, status, priority, needed_by")
      .eq("company_id", companyId)
      .not("status", "in", "(delivered,canceled)")
      .lte("needed_by", effectiveDate)
      .order("needed_by", { ascending: true, nullsFirst: false })
      .limit(1000);
    if (objectScope) query = query.eq("object_id", objectScope.id);
    const { data, error } = await query;
    if (error) throw error;
    for (const row of (data ?? []) as ProcurementRow[]) issues.push(procurementIssue(row, baseDate));
  }

  if (categoryEnabled(mode, "hr") && managerRole(role)) {
    checks.push("incoming_candidate_readiness");
    const assessments = await loadCandidateReadiness({
      client,
      companyId,
      objectId: objectScope?.id,
      date: effectiveDate,
      flightOnly: true,
    });
    for (const item of assessments) {
      if (item.issueTexts.length === 0) continue;
      issues.push(candidateIssue(item, objectScope?.name ?? ""));
    }
  }

  issues.sort((left, right) => {
    if (left.severity !== right.severity) return right.severity - left.severity;
    return left.label.localeCompare(right.label, "ru");
  });
  const counts = categoryCounts(issues);
  const riskScore = issues.reduce((sum, item) => sum + item.severity, 0);
  const scopeName = objectScope?.name ?? "";
  const summaries = !objectScope && mode === "all" ? objectSummary(issues) : [];
  const highlights = [
    ...summaries.map((text) => `[Объект] ${text}`),
    ...issues.map((item) => item.label),
  ];
  const warnings: string[] = [];
  if (categoryEnabled(mode, "attendance") && dateIsOnOrBefore(effectiveDate, baseDate)) {
    warnings.push("Нет положительной отметки табеля — это сигнал проверить данные, а не автоматический вывод, что сотрудник прогулял смену.");
  }
  if (effectiveDate > baseDate) {
    warnings.push("Для будущей даты табель не трактуется как отсутствие: будущие отметки ещё могут не существовать.");
  }
  warnings.push("Goal planner ничего не закрывает и не двигает автоматически: фактическое выполнение задачи, поставки или выхода человека требует подтверждённых данных.");

  const nextSteps: string[] = [];
  if (counts.procurement > 0) nextSteps.push("Скажи «только снабжение», чтобы оставить в сводке только заявки, которые нужны к выбранной дате.");
  if (counts.tasks > 0) nextSteps.push("Скажи «только задачи», чтобы оставить просроченные и невыполненные задачи до выбранной даты.");
  if (counts.attendance > 0) nextSteps.push("Скажи «только табель», чтобы проверить сотрудников без положительной отметки отдельно.");
  if (counts.hr > 0) nextSteps.push("Скажи «только HR», чтобы разобрать готовность прилетающих кандидатов отдельно.");

  return {
    body: readOnlyGoalBody({
      kind: "operational_risk",
      title: scopeName ? `Что требует внимания: ${scopeName}` : "Что требует внимания по компании",
      summary: issues.length === 0
        ? `На ${effectiveDate} по выбранным проверкам критичных отклонений не найдено.`
        : `На ${effectiveDate} найдено сигналов: ${issues.length}. Индекс внимания: ${riskScore}. Табель: ${counts.attendance}, задачи: ${counts.tasks}, снабжение: ${counts.procurement}, HR: ${counts.hr}.`,
      highlights: highlights.length > 0 ? highlights : ["По выбранным проверкам проблем не найдено."],
      warnings,
      nextSteps,
      date: effectiveDate,
      objectName: scopeName,
      prompt: sourcePrompt,
      conversationTopic: "goal_operational_risk",
      conversationMode: mode,
      checks,
      issueCount: issues.length,
      affectedCount: issues.length,
    }),
    status: 200,
  };
}
