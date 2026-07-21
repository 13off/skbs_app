import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

import { buildOperationalAudit } from "./operational_audit.ts";
import { buildPeopleAction } from "./people_actions.ts";
import { buildReportAction } from "./report_actions.ts";
import {
  baseDate,
  clean,
  corsHeaders,
  type EmployeeRow,
  json,
  kind,
  nameMatches,
  normalized,
  requestedDate,
} from "./shared.ts";

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Метод не поддерживается" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !authorization) {
      return json({ error: "Сервис действий не настроен" }, 500);
    }

    const client = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await client.auth.getUser();
    if (userError || !user) {
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const input = await request.json().catch(() => ({}));
    const companyId = clean(input.company_id, 80);
    const requestedObject = clean(input.object_name, 180);
    const prompt = clean(input.prompt, 4000);
    const base = baseDate(input.date);
    if (!companyId || !prompt) {
      return json({ error: "Недостаточно данных запроса" }, 400);
    }

    const { data: profile, error: profileError } = await client
      .from("user_profiles")
      .select("role, object_name, active_company_id, is_active")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.is_active !== true) {
      return json({ error: "Профиль пользователя недоступен" }, 403);
    }
    if (clean(profile.active_company_id, 80) !== companyId) {
      return json(
        { error: "Помощник работает только с активной компанией" },
        403,
      );
    }

    const { data: membership, error: membershipError } = await client
      .from("company_memberships")
      .select("role")
      .eq("company_id", companyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) {
      return json({ error: "Нет доступа к выбранной компании" }, 403);
    }

    const profileRole = clean(profile.role, 30);
    const membershipRole = clean(membership.role, 30);
    const roles = new Set([profileRole, membershipRole]);
    const isAdmin = roles.has("admin") || roles.has("owner");
    const isDeveloper = roles.has("developer");
    const isHr = roles.has("hr");
    const isAccounting = roles.has("accounting") || roles.has("accountant");
    const isForeman = roles.has("foreman");
    const assignedObject = clean(profile.object_name, 180);
    const objectName = isForeman ? assignedObject : requestedObject;
    if (isForeman && !objectName) {
      return json({ error: "Прорабу не назначен объект" }, 403);
    }

    const promptValue = normalized(prompt);
    const wantsOperationalAudit =
      /(?:единый|общий|операционн).*(?:аудит|контрол|проверк).*(?:табел|смен|выплат|чек)/.test(promptValue) ||
      /(?:проверь|сверь|найди).*(?:табел|смен).*(?:выплат|чек)/.test(promptValue) ||
      /(?:проверь|сверь|найди).*(?:выплат|чек).*(?:табел|смен)/.test(promptValue);
    const actionKind = wantsOperationalAudit
      ? "find_operational_anomalies"
      : kind(prompt);
    if (actionKind === "unknown") {
      return json({ error: "Не удалось определить операционное действие" }, 400);
    }
    if (
      ["prepare_employee_update", "create_employee_draft"].includes(actionKind) &&
      !isAdmin &&
      !isHr &&
      !isDeveloper
    ) {
      return json(
        { error: "Работа с сотрудниками доступна руководителю или HR" },
        403,
      );
    }
    if (
      [
        "prepare_payment",
        "find_missing_receipts",
        "find_operational_anomalies",
      ].includes(actionKind) &&
      !isAdmin &&
      !isAccounting &&
      !isDeveloper
    ) {
      return json(
        { error: "Выплаты доступны руководителю или бухгалтеру" },
        403,
      );
    }
    if (
      actionKind === "prepare_candidate_documents" &&
      !isAdmin &&
      !isHr &&
      !isDeveloper
    ) {
      return json(
        { error: "Пакет кандидата доступен руководителю или HR" },
        403,
      );
    }
    if (actionKind === "create_reminder" && !isAdmin && !isDeveloper) {
      return json(
        { error: "Системные напоминания доступны руководителю или разработчику" },
        403,
      );
    }

    let employeeQuery: any = client
      .from("employees")
      .select("id, fio, position, phone, object_name, daily_rate")
      .eq("company_id", companyId)
      .is("archived_at", null)
      .order("fio");
    if (objectName) employeeQuery = employeeQuery.eq("object_name", objectName);
    const { data: employeeRows, error: employeeError } = await employeeQuery;
    if (employeeError) throw employeeError;
    const employees = (employeeRows ?? []) as EmployeeRow[];
    const matchedEmployees = employees.filter((employee) =>
      nameMatches(prompt, employee.fio)
    );
    const employee = matchedEmployees.length === 1 ? matchedEmployees[0] : null;
    const date = requestedDate(prompt, base);

    if (actionKind === "find_operational_anomalies") {
      return await buildOperationalAudit({
        client,
        companyId,
        objectName,
        date,
        base,
        prompt,
        employees,
      });
    }

    const peopleResult = buildPeopleAction({
      actionKind,
      prompt,
      objectName,
      date,
      employee,
    });
    if (peopleResult != null) return peopleResult;

    const reportResult = await buildReportAction({
      client,
      actionKind,
      companyId,
      objectName,
      date,
      base,
      prompt,
      employees,
    });
    if (reportResult != null) return reportResult;

    return json({ error: "Действие пока не поддерживается" }, 400);
  } catch (error) {
    console.error("ai operational draft failed", error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
