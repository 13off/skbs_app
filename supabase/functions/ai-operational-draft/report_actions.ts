import {
  actionResponse,
  clean,
  type CandidateRow,
  dateKey,
  type EmployeeRow,
  json,
  nameMatches,
  requestedMonth,
} from "./shared.ts";

type AttendanceAuditState = {
  employee: EmployeeRow;
  recordedDays: number;
  totalShifts: number;
  invalidEntries: Array<{ date: string; reason: string }>;
};

type AttendanceAuditIssue = {
  severity: "critical" | "attention";
  issue_type: "invalid_entries" | "no_entries" | "no_worked_shifts";
  employee_id: string;
  employee_name: string;
  object_name: string;
  total_shifts: number;
  recorded_days: number;
  details: Array<{ date: string; reason: string }>;
  message: string;
};

function endOfMonth(month: string): string {
  const [yearText, monthText] = month.split("-");
  const value = new Date(Date.UTC(Number(yearText), Number(monthText), 0));
  return dateKey(value.getUTCFullYear(), value.getUTCMonth() + 1, value.getUTCDate());
}

export async function buildReportAction({
  client,
  actionKind,
  companyId,
  objectName,
  date,
  base,
  prompt,
  employees,
}: {
  client: any;
  actionKind: string;
  companyId: string;
  objectName: string;
  date: string;
  base: Date;
  prompt: string;
  employees: EmployeeRow[];
}): Promise<Response | null> {
  if (actionKind === "find_missing_receipts") {
    const month = requestedMonth(prompt, base);
    const [yearText, monthText] = month.split("-");
    let scopedEmployees = employees;
    if (!objectName) {
      const { data: allRows, error: allError } = await client
        .from("employees")
        .select("id, fio, position, phone, object_name, daily_rate")
        .eq("company_id", companyId)
        .is("archived_at", null);
      if (allError) throw allError;
      scopedEmployees = (allRows ?? []) as EmployeeRow[];
    }
    const employeeById = new Map(
      scopedEmployees.map((item) => [item.id, item]),
    );
    const employeeIds = [...employeeById.keys()];
    let rows: any[] = [];
    if (employeeIds.length > 0) {
      const { data: paymentRows, error: paymentError } = await client
        .from("payments")
        .select("id, employee_id, payment_date, amount, payment_type, comment")
        .eq("company_id", companyId)
        .eq("period_year", Number(yearText))
        .eq("period_month", Number(monthText))
        .in("employee_id", employeeIds)
        .order("payment_date", { ascending: false });
      if (paymentError) throw paymentError;
      const paymentIds = (paymentRows ?? []).map((row: any) => clean(row.id, 80));
      const receiptPaymentIds = new Set<string>();
      if (paymentIds.length > 0) {
        const { data: receiptRows, error: receiptError } = await client
          .from("payment_receipts")
          .select("payment_id")
          .eq("company_id", companyId)
          .in("payment_id", paymentIds);
        if (receiptError) throw receiptError;
        for (const receipt of receiptRows ?? []) {
          receiptPaymentIds.add(clean(receipt.payment_id, 80));
        }
      }
      rows = (paymentRows ?? [])
        .filter((row: any) => !receiptPaymentIds.has(clean(row.id, 80)))
        .map((row: any) => {
          const worker = employeeById.get(clean(row.employee_id, 80));
          return {
            payment_id: row.id,
            employee_id: row.employee_id,
            employee_name: worker?.fio ?? "Сотрудник",
            object_name: worker?.object_name ?? "",
            payment_date: row.payment_date,
            amount: row.amount,
            payment_type: row.payment_type,
            comment: row.comment,
          };
        });
    }
    return json(actionResponse({
      type: actionKind,
      title: "Выплаты без чеков найдены",
      button: "Открыть список",
      summary: rows.length === 0
        ? `За ${month} выплат без чеков не найдено.`
        : `За ${month} без чеков: ${rows.length}.`,
      highlights: [
        `Период: ${month}`,
        `Найдено: ${rows.length}`,
        objectName ? `Объект: ${objectName}` : "Все доступные объекты",
      ],
      warnings: rows.length > 0
        ? ["Список сформирован только для проверки и ничего не изменяет."]
        : [],
      objectName,
      date,
      payload: { month, object_name: objectName, rows, source_prompt: prompt },
    }));
  }

  if (actionKind === "find_timesheet_gaps") {
    const month = requestedMonth(prompt, base);
    const startDate = `${month}-01`;
    const endDate = endOfMonth(month);
    const states = new Map<string, AttendanceAuditState>(
      employees.map((employee) => [
        employee.id,
        {
          employee,
          recordedDays: 0,
          totalShifts: 0,
          invalidEntries: [],
        },
      ]),
    );
    const employeeIds = [...states.keys()];

    if (employeeIds.length > 0) {
      let attendanceQuery = client
        .from("attendance")
        .select("employee_id, work_date, object_name, status, shifts")
        .eq("company_id", companyId)
        .gte("work_date", startDate)
        .lte("work_date", endDate)
        .in("employee_id", employeeIds)
        .order("work_date");
      if (objectName) attendanceQuery = attendanceQuery.eq("object_name", objectName);
      const { data: attendanceRows, error: attendanceError } = await attendanceQuery;
      if (attendanceError) throw attendanceError;

      for (const row of attendanceRows ?? []) {
        const state = states.get(clean(row.employee_id, 80));
        if (!state) continue;
        const shifts = Number(row.shifts ?? 0);
        const status = clean(row.status, 40);
        const workDate = clean(row.work_date, 10);
        state.recordedDays++;
        if (Number.isFinite(shifts)) state.totalShifts += shifts;

        const reasons: string[] = [];
        if (!Number.isFinite(shifts) || shifts < 0 || shifts > 3) {
          reasons.push(`значение смен вне диапазона 0–3: ${row.shifts ?? "пусто"}`);
        }
        if (status === "worked" && (!Number.isFinite(shifts) || shifts <= 0)) {
          reasons.push("статус «worked», но смены равны нулю");
        }
        if (status === "no_show" && Number.isFinite(shifts) && shifts > 0) {
          reasons.push("статус «no_show», но указаны отработанные смены");
        }
        for (const reason of reasons) {
          state.invalidEntries.push({ date: workDate, reason });
        }
      }
    }

    const issues: AttendanceAuditIssue[] = [...states.values()].flatMap((state) => {
      if (state.invalidEntries.length > 0) {
        return [{
          severity: "critical" as const,
          issue_type: "invalid_entries" as const,
          employee_id: state.employee.id,
          employee_name: state.employee.fio,
          object_name: state.employee.object_name,
          total_shifts: state.totalShifts,
          recorded_days: state.recordedDays,
          details: state.invalidEntries,
          message: `${state.invalidEntries.length} некорректных отметок`,
        }];
      }
      if (state.recordedDays === 0) {
        return [{
          severity: "attention" as const,
          issue_type: "no_entries" as const,
          employee_id: state.employee.id,
          employee_name: state.employee.fio,
          object_name: state.employee.object_name,
          total_shifts: 0,
          recorded_days: 0,
          details: [],
          message: "за период нет ни одной отметки табеля",
        }];
      }
      if (state.totalShifts <= 0) {
        return [{
          severity: "attention" as const,
          issue_type: "no_worked_shifts" as const,
          employee_id: state.employee.id,
          employee_name: state.employee.fio,
          object_name: state.employee.object_name,
          total_shifts: state.totalShifts,
          recorded_days: state.recordedDays,
          details: [],
          message: "отметки есть, но отработанных смен нет",
        }];
      }
      return [];
    });
    issues.sort((left, right) => {
      if (left.severity !== right.severity) {
        return left.severity === "critical" ? -1 : 1;
      }
      return left.employee_name.localeCompare(right.employee_name, "ru");
    });
    const criticalCount = issues.filter((item) => item.severity === "critical").length;
    const attentionCount = issues.length - criticalCount;
    const preview = issues.slice(0, 12).map(
      (item) => `${item.employee_name}: ${item.message}`,
    );
    const highlights = [
      `Период: ${month}`,
      `Проверено сотрудников: ${employees.length}`,
      `Критичные несоответствия: ${criticalCount}`,
      `Требуют внимания: ${attentionCount}`,
      objectName ? `Объект: ${objectName}` : "Все доступные объекты",
      ...preview,
    ];
    if (issues.length > preview.length) {
      highlights.push(`Ещё сотрудников: ${issues.length - preview.length}`);
    }

    return json(actionResponse({
      type: "open_period_timesheet",
      title: issues.length === 0
        ? "Табель проверен"
        : "В табеле есть контрольные вопросы",
      button: "Открыть месячный табель",
      summary: issues.length === 0
        ? `За ${month} явных проблем не найдено.`
        : `За ${month}: критичных ${criticalCount}, требуют внимания ${attentionCount}.`,
      highlights,
      warnings: [
        "Отсутствие отметок или нулевые смены показаны как контрольный вопрос, а не подтверждённая ошибка: приложение не знает плановый график и дату фактического выхода.",
        "Проверка ничего не изменяет. После подтверждения откроется штатный месячный табель на нужном периоде.",
      ],
      objectName,
      date,
      payload: {
        month,
        object_name: objectName,
        audit_kind: actionKind,
        critical_count: criticalCount,
        attention_count: attentionCount,
        issues,
        source_prompt: prompt,
      },
    }));
  }

  if (actionKind === "open_period_timesheet") {
    const month = requestedMonth(prompt, base);
    return json(actionResponse({
      type: actionKind,
      title: "Месячный табель подготовлен",
      button: "Открыть месячный табель",
      summary: `Период: ${month}.`,
      highlights: [
        `Период: ${month}`,
        objectName ? `Объект: ${objectName}` : "Все доступные объекты",
      ],
      warnings: ["Откроется действующий отчёт приложения."],
      objectName,
      date,
      payload: { month, object_name: objectName, source_prompt: prompt },
    }));
  }

  if (actionKind === "prepare_work_act") {
    return json(actionResponse({
      type: actionKind,
      title: "Черновик акта подготовлен",
      button: "Открыть акт выполненных работ",
      summary: `Выполненные задачи за ${date}.`,
      highlights: [
        `Дата: ${date}`,
        objectName ? `Объект: ${objectName}` : "Все доступные объекты",
      ],
      warnings: ["В акт попадут только задачи со статусом «Выполнено»."],
      objectName,
      date,
      payload: { date, object_name: objectName, source_prompt: prompt },
    }));
  }

  if (actionKind === "prepare_candidate_documents") {
    const { data: candidateRows, error: candidateError } = await client
      .from("recruitment_applications")
      .select(
        "id, full_name, phone, citizenship, position_title, status, ready_date, consent_personal_data, object_id",
      )
      .eq("company_id", companyId)
      .is("archived_at", null)
      .order("updated_at", { ascending: false });
    if (candidateError) throw candidateError;
    const matches = ((candidateRows ?? []) as CandidateRow[]).filter(
      (candidate) => nameMatches(prompt, candidate.full_name),
    );
    const candidate = matches.length === 1 ? matches[0] : null;
    if (!candidate) {
      return json({ error: "Укажи одного кандидата из подбора" }, 400);
    }

    let candidateObjectName = "";
    if (candidate.object_id) {
      const { data: objectRow, error: objectError } = await client
        .from("objects")
        .select("name")
        .eq("company_id", companyId)
        .eq("id", candidate.object_id)
        .maybeSingle();
      if (objectError) throw objectError;
      candidateObjectName = clean(objectRow?.name, 180);
    }

    const { data: documentRows, error: documentError } = await client
      .from("recruitment_documents")
      .select("document_type, original_name, mime_type")
      .eq("company_id", companyId)
      .eq("application_id", candidate.id)
      .eq("is_test_copy", false);
    if (documentError) throw documentError;
    const existingDocuments = (documentRows ?? []).map((row: any) => ({
      document_type: row.document_type,
      original_name: row.original_name,
      mime_type: row.mime_type,
    }));
    const existingTypes = new Set(
      existingDocuments.map((row: any) => clean(row.document_type, 80)),
    );
    const required = ["passport_main", "snils", "inn"];
    const missingDocuments = required.filter((type) => !existingTypes.has(type));
    return json(actionResponse({
      type: actionKind,
      title: "Пакет документов кандидата подготовлен",
      button: "Открыть пакет кандидата",
      summary:
        `${candidate.full_name}: документов ${existingDocuments.length}, не хватает ${missingDocuments.length}.`,
      highlights: [
        `Кандидат: ${candidate.full_name}`,
        `Должность: ${candidate.position_title || "Не указана"}`,
        `Объект: ${candidateObjectName || "Не указан"}`,
        `Получено файлов: ${existingDocuments.length}`,
        `Не хватает: ${missingDocuments.length}`,
      ],
      warnings: [
        "Персональные реквизиты не передаются ИИ. Пакет собирается локально после повторной проверки доступа.",
      ],
      objectName: candidateObjectName,
      date,
      payload: {
        application_id: candidate.id,
        full_name: candidate.full_name,
        phone: candidate.phone,
        citizenship: candidate.citizenship,
        position_title: candidate.position_title,
        object_name: candidateObjectName,
        status: candidate.status,
        ready_date: candidate.ready_date,
        consent_personal_data: candidate.consent_personal_data,
        existing_documents: existingDocuments,
        missing_documents: missingDocuments,
        source_prompt: prompt,
      },
    }));
  }

  return null;
}
