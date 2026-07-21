import {
  actionResponse,
  clean,
  type CandidateRow,
  type EmployeeRow,
  json,
  nameMatches,
  requestedMonth,
} from "./shared.ts";

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
        "id, full_name, phone, citizenship, position_title, status, consent_personal_data, object_id",
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
    const required = ["passport", "snils", "inn"];
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
        `Получено файлов: ${existingDocuments.length}`,
        `Не хватает: ${missingDocuments.length}`,
      ],
      warnings: [
        "Персональные реквизиты не передаются ИИ. Пакет показывает только статус и исходные формы.",
      ],
      objectName,
      date,
      payload: {
        application_id: candidate.id,
        full_name: candidate.full_name,
        phone: candidate.phone,
        citizenship: candidate.citizenship,
        position_title: candidate.position_title,
        status: candidate.status,
        consent_personal_data: candidate.consent_personal_data,
        existing_documents: existingDocuments,
        missing_documents: missingDocuments,
        source_prompt: prompt,
      },
    }));
  }

  return null;
}
