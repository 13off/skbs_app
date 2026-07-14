import { clean, dataOrEmpty, dateRu, dateTimeRu, money, num, ranked, section } from "./shared.ts";
import { applyPeriod, PeriodFilter } from "./period.ts";
import { SearchFlags, SearchResultParts } from "./core_search.ts";

export async function searchAdmin({
  client,
  companyId,
  objectName,
  tokens,
  normalized,
  period,
  employees,
  objects,
  matchedEmployee,
  flags,
  isAdmin,
}: {
  client: any;
  companyId: string;
  objectName: string;
  tokens: string[];
  normalized: string;
  period: PeriodFilter;
  employees: any[];
  objects: any[];
  matchedEmployee: any | null;
  flags: SearchFlags;
  isAdmin: boolean;
}): Promise<SearchResultParts> {
  const sections: string[] = [];
  const highlights: string[] = [];
  const warnings: string[] = [];

  if (!isAdmin) {
    if (
      flags.payments ||
      flags.receipts ||
      flags.users ||
      flags.company ||
      flags.invitations
    ) {
      warnings.push(
        "Финансы, управление компанией и приглашения доступны в поиске только администратору.",
      );
    }
    return { sections, highlights, warnings };
  }

  const employeeById = new Map<string, any>(
    employees.map((employee: any) => [String(employee.id), employee]),
  );
  const scopedIds = employees
    .map((employee: any) => employee.id)
    .filter(Boolean);

  let payments: any[] = [];
  if (flags.payments || flags.receipts || flags.broad) {
    let query: any = client
      .from("payments")
      .select("id, employee_id, payment_date, amount, comment, payment_type, period_year, period_month")
      .eq("company_id", companyId)
      .order("payment_date", { ascending: false })
      .limit(500);
    query = applyPeriod(query, "payment_date", period);
    if (objectName && scopedIds.length > 0) {
      query = query.in("employee_id", scopedIds);
    }
    payments = await dataOrEmpty(query, "search payments");
  }

  if (flags.payments || flags.broad) {
    const found = ranked(
      payments,
      tokens,
      (payment: any) => {
        const employee = employeeById.get(String(payment.employee_id));
        return [
          employee?.fio,
          employee?.position,
          payment.payment_date,
          payment.amount,
          payment.payment_type,
          payment.comment,
          payment.period_year,
          payment.period_month,
        ];
      },
      25,
    ).filter((payment: any) =>
      !matchedEmployee ||
      String(payment.employee_id) === String(matchedEmployee.id)
    );
    const lines = found.map((payment: any) => {
      const employee = employeeById.get(String(payment.employee_id));
      return [
        `• ${dateRu(payment.payment_date)}`,
        clean(employee?.fio, 180) || "Сотрудник",
        money(payment.amount),
        clean(payment.payment_type, 100),
        clean(payment.comment, 220),
      ].filter(Boolean).join(" • ");
    });
    section(sections, "Выплаты", lines);
    if (lines.length > 0) {
      const total = found.reduce(
        (sum: number, payment: any) => sum + num(payment.amount),
        0,
      );
      highlights.push(`Выплаты: ${lines.length} на ${money(total)}`);
    }
  }

  if (flags.receipts || flags.broad) {
    let query: any = client
      .from("payment_receipts")
      .select("employee_id, file_name, content_type, created_at")
      .eq("company_id", companyId)
      .order("created_at", { ascending: false })
      .limit(500);
    if (objectName && scopedIds.length > 0) {
      query = query.in("employee_id", scopedIds);
    }
    const receipts = await dataOrEmpty(query, "search receipts");
    const found = ranked(
      receipts,
      tokens,
      (receipt: any) => {
        const employee = employeeById.get(String(receipt.employee_id));
        return [
          employee?.fio,
          receipt.file_name,
          receipt.content_type,
          receipt.created_at,
        ];
      },
      15,
    ).filter((receipt: any) =>
      !matchedEmployee ||
      String(receipt.employee_id) === String(matchedEmployee.id)
    );
    const lines = found.map((receipt: any) => {
      const employee = employeeById.get(String(receipt.employee_id));
      return [
        `• ${dateTimeRu(receipt.created_at)}`,
        clean(employee?.fio, 180) || "Сотрудник",
        clean(receipt.file_name, 240),
        clean(receipt.content_type, 100),
      ].filter(Boolean).join(" • ");
    });
    section(sections, "Чеки и подтверждения", lines);
    if (lines.length > 0) highlights.push(`Чеки: ${lines.length}`);
  }

  if (flags.users || flags.broad) {
    const memberships = await dataOrEmpty(
      client
        .from("company_memberships")
        .select("user_id, role, is_active, created_at")
        .eq("company_id", companyId)
        .order("created_at"),
      "search memberships",
    );
    const ids = memberships.map((item: any) => item.user_id).filter(Boolean);
    const profiles = ids.length > 0
      ? await dataOrEmpty(
          client
            .from("user_profiles")
            .select("id, email, full_name, object_name, is_active")
            .in("id", ids),
          "search profiles",
        )
      : [];
    const profileById = new Map<string, any>(
      profiles.map((item: any) => [String(item.id), item]),
    );
    const joined = memberships.map((item: any) => ({
      ...item,
      profile: profileById.get(String(item.user_id)),
    }));
    const found = ranked(
      joined,
      tokens,
      (item: any) => [
        item.profile?.full_name,
        item.profile?.email,
        item.role,
        item.role === "admin" || item.role === "owner" ? "админ" : "прораб",
        item.profile?.object_name,
      ],
      20,
    ).filter((item: any) => {
      if (/админ/.test(normalized)) {
        return item.role === "admin" || item.role === "owner";
      }
      if (/прораб/.test(normalized)) return item.role === "foreman";
      return true;
    });
    const lines = found.map((item: any) => [
      `• ${clean(item.profile?.full_name, 180) || clean(item.profile?.email, 180) || "Пользователь"}`,
      item.role === "admin" || item.role === "owner" ? "админ" : "прораб",
      clean(item.profile?.object_name, 180),
      item.is_active ? "активен" : "неактивен",
    ].filter(Boolean).join(" • "));
    section(sections, "Пользователи компании", lines);
    if (lines.length > 0) highlights.push(`Пользователи: ${lines.length}`);
  }

  if (flags.company) {
    const companies = await dataOrEmpty(
      client
        .from("companies")
        .select("name, status, plan_code, billing_status, seat_limit, object_limit")
        .eq("id", companyId)
        .limit(1),
      "search company",
    );
    const lines = companies.map((company: any) => [
      `• ${clean(company.name, 180)}`,
      `статус: ${clean(company.status, 80)}`,
      `тариф: ${clean(company.plan_code, 80)}`,
      `оплата: ${clean(company.billing_status, 80)}`,
      `мест: ${num(company.seat_limit)}`,
      `объектов: ${num(company.object_limit)}`,
    ].filter(Boolean).join(" • "));
    section(sections, "Компания", lines);
  }

  if (flags.invitations || flags.broad) {
    const invitations = await dataOrEmpty(
      client
        .from("company_invitations")
        .select("email, role, object_id, status, expires_at")
        .eq("company_id", companyId)
        .order("created_at", { ascending: false })
        .limit(200),
      "search invitations",
    );
    const objectById = new Map<string, any>(
      objects.map((object: any) => [String(object.id), object]),
    );
    const found = ranked(
      invitations,
      tokens,
      (invite: any) => [
        invite.email,
        invite.role,
        invite.status,
        invite.status === "pending" ? "ожидает ожидание" : "",
        objectById.get(String(invite.object_id))?.name,
      ],
      20,
    );
    const lines = found.map((invite: any) => [
      `• ${clean(invite.email, 180)}`,
      clean(invite.role, 80),
      clean(objectById.get(String(invite.object_id))?.name, 180),
      clean(invite.status, 80),
      invite.expires_at ? `до ${dateTimeRu(invite.expires_at)}` : "",
    ].filter(Boolean).join(" • "));
    section(sections, "Приглашения", lines);
    if (lines.length > 0) highlights.push(`Приглашения: ${lines.length}`);
  }

  if (flags.company) {
    const requests = await dataOrEmpty(
      client
        .from("company_plan_requests")
        .select("requested_plan, note, status, created_at")
        .eq("company_id", companyId)
        .order("created_at", { ascending: false })
        .limit(50),
      "search plan requests",
    );
    const found = ranked(
      requests,
      tokens,
      (item: any) => [
        item.requested_plan,
        item.note,
        item.status,
        item.created_at,
      ],
      10,
    );
    const lines = found.map((item: any) => [
      `• ${dateTimeRu(item.created_at)}`,
      clean(item.requested_plan, 100),
      clean(item.status, 80),
      clean(item.note, 240),
    ].filter(Boolean).join(" • "));
    section(sections, "Заявки на тариф", lines);
  }

  return { sections, highlights, warnings };
}
