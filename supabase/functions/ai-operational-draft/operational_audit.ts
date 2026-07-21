import {
  actionResponse,
  clean,
  dateKey,
  type EmployeeRow,
  json,
  normalized,
  requestedMonth,
} from "./shared.ts";

type AuditIssue = {
  severity: "critical" | "attention";
  category: "attendance" | "payments" | "objects";
  issue_type: string;
  employee_id: string;
  employee_name: string;
  object_name: string;
  message: string;
  details: Record<string, unknown>;
};

function endOfMonth(month: string): string {
  const [yearText, monthText] = month.split("-");
  const value = new Date(Date.UTC(Number(yearText), Number(monthText), 0));
  return dateKey(value.getUTCFullYear(), value.getUTCMonth() + 1, value.getUTCDate());
}

function money(value: unknown): number {
  const result = Number(value ?? 0);
  return Number.isFinite(result) ? result : 0;
}

export async function buildOperationalAudit({
  client,
  companyId,
  objectName,
  date,
  base,
  prompt,
  employees,
}: {
  client: any;
  companyId: string;
  objectName: string;
  date: string;
  base: Date;
  prompt: string;
  employees: EmployeeRow[];
}): Promise<Response> {
  const month = requestedMonth(prompt, base);
  const [yearText, monthText] = month.split("-");
  const startDate = `${month}-01`;
  const finishDate = endOfMonth(month);
  const employeeById = new Map(employees.map((item) => [item.id, item]));
  const employeeIds = [...employeeById.keys()];
  const issues: AuditIssue[] = [];
  const shiftsByEmployee = new Map<string, number>();
  const recordedDaysByEmployee = new Map<string, number>();

  let attendanceRows: any[] = [];
  let paymentRows: any[] = [];
  if (employeeIds.length > 0) {
    let attendanceQuery = client
      .from("attendance")
      .select("employee_id, work_date, object_name, status, shifts")
      .eq("company_id", companyId)
      .gte("work_date", startDate)
      .lte("work_date", finishDate)
      .in("employee_id", employeeIds)
      .order("work_date");
    if (objectName) attendanceQuery = attendanceQuery.eq("object_name", objectName);
    const { data: attendanceData, error: attendanceError } = await attendanceQuery;
    if (attendanceError) throw attendanceError;
    attendanceRows = attendanceData ?? [];

    const { data: paymentData, error: paymentError } = await client
      .from("payments")
      .select(
        "id, employee_id, object_id, payment_date, amount, payment_type, comment",
      )
      .eq("company_id", companyId)
      .eq("period_year", Number(yearText))
      .eq("period_month", Number(monthText))
      .in("employee_id", employeeIds)
      .order("payment_date", { ascending: false });
    if (paymentError) throw paymentError;
    paymentRows = paymentData ?? [];
  }

  for (const row of attendanceRows) {
    const employeeId = clean(row.employee_id, 80);
    const employee = employeeById.get(employeeId);
    if (!employee) continue;
    const shifts = Number(row.shifts ?? 0);
    const status = clean(row.status, 40);
    const workDate = clean(row.work_date, 10);
    shiftsByEmployee.set(employeeId, (shiftsByEmployee.get(employeeId) ?? 0) + money(shifts));
    recordedDaysByEmployee.set(
      employeeId,
      (recordedDaysByEmployee.get(employeeId) ?? 0) + 1,
    );

    const reasons: string[] = [];
    if (!Number.isFinite(shifts) || shifts < 0 || shifts > 3) {
      reasons.push(`смены вне диапазона 0–3: ${row.shifts ?? "пусто"}`);
    }
    if (status === "worked" && (!Number.isFinite(shifts) || shifts <= 0)) {
      reasons.push("статус «worked», но смены равны нулю");
    }
    if (status === "no_show" && Number.isFinite(shifts) && shifts > 0) {
      reasons.push("статус «no_show», но указаны отработанные смены");
    }
    if (
      normalized(row.object_name) &&
      normalized(employee.object_name) &&
      normalized(row.object_name) !== normalized(employee.object_name)
    ) {
      reasons.push(`табель относится к объекту «${clean(row.object_name, 180)}»`);
    }
    if (reasons.length > 0) {
      issues.push({
        severity: "critical",
        category: reasons.some((item) => item.includes("объекту"))
          ? "objects"
          : "attendance",
        issue_type: "invalid_attendance",
        employee_id: employeeId,
        employee_name: employee.fio,
        object_name: employee.object_name,
        message: `${workDate}: ${reasons.join("; ")}`,
        details: { work_date: workDate, shifts: row.shifts, status, reasons },
      });
    }
  }

  for (const employee of employees) {
    const recordedDays = recordedDaysByEmployee.get(employee.id) ?? 0;
    const shifts = shiftsByEmployee.get(employee.id) ?? 0;
    if (recordedDays === 0) {
      issues.push({
        severity: "attention",
        category: "attendance",
        issue_type: "no_attendance_entries",
        employee_id: employee.id,
        employee_name: employee.fio,
        object_name: employee.object_name,
        message: "за период нет ни одной отметки табеля",
        details: { recorded_days: 0, total_shifts: 0 },
      });
    } else if (shifts <= 0) {
      issues.push({
        severity: "attention",
        category: "attendance",
        issue_type: "no_worked_shifts",
        employee_id: employee.id,
        employee_name: employee.fio,
        object_name: employee.object_name,
        message: "отметки есть, но отработанных смен нет",
        details: { recorded_days: recordedDays, total_shifts: shifts },
      });
    }
  }

  const paymentIds = paymentRows.map((row) => clean(row.id, 80)).filter(Boolean);
  const receiptPaymentIds = new Set<string>();
  if (paymentIds.length > 0) {
    const { data: receipts, error: receiptError } = await client
      .from("payment_receipts")
      .select("payment_id")
      .eq("company_id", companyId)
      .in("payment_id", paymentIds);
    if (receiptError) throw receiptError;
    for (const receipt of receipts ?? []) {
      receiptPaymentIds.add(clean(receipt.payment_id, 80));
    }
  }

  const objectIds = [...new Set(
    paymentRows.map((row) => clean(row.object_id, 80)).filter(Boolean),
  )];
  const objectNameById = new Map<string, string>();
  if (objectIds.length > 0) {
    const { data: objectRows, error: objectError } = await client
      .from("objects")
      .select("id, name")
      .eq("company_id", companyId)
      .in("id", objectIds);
    if (objectError) throw objectError;
    for (const row of objectRows ?? []) {
      objectNameById.set(clean(row.id, 80), clean(row.name, 180));
    }
  }

  const paymentsByEmployee = new Map<string, number>();
  const duplicateGroups = new Map<string, any[]>();
  for (const row of paymentRows) {
    const employeeId = clean(row.employee_id, 80);
    const employee = employeeById.get(employeeId);
    if (!employee) continue;
    const amount = money(row.amount);
    paymentsByEmployee.set(
      employeeId,
      (paymentsByEmployee.get(employeeId) ?? 0) + amount,
    );
    const paymentId = clean(row.id, 80);
    const paymentObject = objectNameById.get(clean(row.object_id, 80)) ?? "";

    if (!receiptPaymentIds.has(paymentId)) {
      issues.push({
        severity: "attention",
        category: "payments",
        issue_type: "missing_receipt",
        employee_id: employeeId,
        employee_name: employee.fio,
        object_name: paymentObject || employee.object_name,
        message: `${clean(row.payment_date, 10)}: выплата ${amount} ₽ без чека`,
        details: {
          payment_id: paymentId,
          payment_date: row.payment_date,
          amount,
          payment_type: row.payment_type,
          comment: row.comment,
        },
      });
    }
    if (amount <= 0) {
      issues.push({
        severity: "critical",
        category: "payments",
        issue_type: "invalid_payment_amount",
        employee_id: employeeId,
        employee_name: employee.fio,
        object_name: paymentObject || employee.object_name,
        message: `некорректная сумма выплаты: ${row.amount ?? "пусто"}`,
        details: { payment_id: paymentId, amount: row.amount },
      });
    }
    if (
      paymentObject &&
      normalized(employee.object_name) &&
      normalized(paymentObject) !== normalized(employee.object_name)
    ) {
      issues.push({
        severity: "critical",
        category: "objects",
        issue_type: "payment_object_mismatch",
        employee_id: employeeId,
        employee_name: employee.fio,
        object_name: employee.object_name,
        message: `выплата проведена по объекту «${paymentObject}»`,
        details: { payment_id: paymentId, payment_object_name: paymentObject },
      });
    }

    const duplicateKey = [
      employeeId,
      clean(row.payment_date, 10),
      amount.toFixed(2),
      clean(row.payment_type, 40),
    ].join("|");
    const group = duplicateGroups.get(duplicateKey) ?? [];
    group.push(row);
    duplicateGroups.set(duplicateKey, group);
  }

  for (const group of duplicateGroups.values()) {
    if (group.length < 2) continue;
    const first = group[0];
    const employeeId = clean(first.employee_id, 80);
    const employee = employeeById.get(employeeId);
    if (!employee) continue;
    issues.push({
      severity: "critical",
      category: "payments",
      issue_type: "duplicate_payment",
      employee_id: employeeId,
      employee_name: employee.fio,
      object_name: employee.object_name,
      message: `${group.length} одинаковые выплаты за ${clean(first.payment_date, 10)}`,
      details: {
        payment_ids: group.map((row) => row.id),
        payment_date: first.payment_date,
        amount: first.amount,
        payment_type: first.payment_type,
      },
    });
  }

  for (const employee of employees) {
    const paid = paymentsByEmployee.get(employee.id) ?? 0;
    if (paid <= 0) continue;
    const shifts = shiftsByEmployee.get(employee.id) ?? 0;
    const accrued = shifts * money(employee.daily_rate);
    if (accrued <= 0) {
      issues.push({
        severity: "critical",
        category: "payments",
        issue_type: "payment_without_accrual",
        employee_id: employee.id,
        employee_name: employee.fio,
        object_name: employee.object_name,
        message: `выплачено ${paid} ₽ при нулевом начислении по табелю`,
        details: { paid, accrued, shifts, daily_rate: employee.daily_rate },
      });
    } else if (paid > accrued) {
      issues.push({
        severity: "critical",
        category: "payments",
        issue_type: "payments_exceed_accrual",
        employee_id: employee.id,
        employee_name: employee.fio,
        object_name: employee.object_name,
        message: `выплаты ${paid} ₽ превышают начисление ${accrued} ₽`,
        details: { paid, accrued, shifts, daily_rate: employee.daily_rate },
      });
    }
  }

  issues.sort((left, right) => {
    if (left.severity !== right.severity) {
      return left.severity === "critical" ? -1 : 1;
    }
    if (left.category !== right.category) {
      return left.category.localeCompare(right.category);
    }
    return left.employee_name.localeCompare(right.employee_name, "ru");
  });

  const criticalCount = issues.filter((item) => item.severity === "critical").length;
  const attentionCount = issues.length - criticalCount;
  const attendanceCount = issues.filter((item) => item.category === "attendance").length;
  const paymentCount = issues.filter((item) => item.category === "payments").length;
  const objectCount = issues.filter((item) => item.category === "objects").length;

  return json(actionResponse({
    type: "find_operational_anomalies",
    title: issues.length === 0
      ? "Операционный контроль пройден"
      : "Найдены контрольные вопросы",
    button: "Открыть контрольный отчёт",
    summary: issues.length === 0
      ? `За ${month} явных проблем табеля и выплат не найдено.`
      : `За ${month}: критичных ${criticalCount}, требуют внимания ${attentionCount}.`,
    highlights: [
      `Период: ${month}`,
      `Проверено сотрудников: ${employees.length}`,
      `Табель: ${attendanceCount}`,
      `Выплаты: ${paymentCount}`,
      `Объекты: ${objectCount}`,
      `Критичные: ${criticalCount}`,
      `Требуют внимания: ${attentionCount}`,
      objectName ? `Объект: ${objectName}` : "Все доступные объекты",
    ],
    warnings: [
      "Отсутствие табеля показано как контрольный вопрос: приложение не знает плановый график и дату фактического выхода.",
      "Сравнение выплат с начислением использует текущую ставку карточки и требует ручной проверки при изменении ставки внутри месяца.",
      "Отчёт ничего не изменяет и не удаляет. Исправления выполняются только в штатных экранах.",
    ],
    objectName,
    date,
    payload: {
      month,
      object_name: objectName,
      critical_count: criticalCount,
      attention_count: attentionCount,
      attendance_count: attendanceCount,
      payment_count: paymentCount,
      object_count: objectCount,
      issues,
      source_prompt: prompt,
    },
  }));
}
