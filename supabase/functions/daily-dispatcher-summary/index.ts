import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function text(value: unknown, max = 2000) {
  return String(value ?? "").trim().slice(0, max);
}

function numberValue(value: unknown) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function formatDateRu(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  return match ? `${match[3]}.${match[2]}.${match[1]}` : value;
}

function responseText(value: any) {
  if (typeof value?.output_text === "string") return value.output_text.trim();
  const parts: string[] = [];
  for (const item of value?.output ?? []) {
    for (const content of item?.content ?? []) {
      if (typeof content?.text === "string") parts.push(content.text);
    }
  }
  return parts.join("\n").trim();
}

async function aiCommentary(payload: unknown) {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) return "";

  try {
    const result = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") || "gpt-5-mini",
        instructions:
          "Ты ИИ-диспетчер строительной компании. Составь короткую ежедневную сводку на русском языке. Не выдумывай факты. Сначала итог дня, затем риски, затем 2-4 конкретных действия. Не используй markdown-таблицы. До 1200 символов.",
        input: JSON.stringify(payload),
        max_output_tokens: 700,
      }),
    });
    if (!result.ok) return "";
    return responseText(await result.json());
  } catch (_) {
    return "";
  }
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return response({ error: "Метод не поддерживается" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return response({ error: "Сервис не настроен" }, 500);
  }

  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let runId = "";
  try {
    const input = await request.json().catch(() => ({}));
    runId = text(input.run_id, 80);
    const dispatchToken = text(input.dispatch_token, 80);
    if (!runId || !dispatchToken) {
      return response({ error: "Не указан запуск" }, 400);
    }

    const { data: run, error: runError } = await client
      .from("dispatcher_summary_runs")
      .select("id,company_id,summary_date,status,dispatch_token,attempts")
      .eq("id", runId)
      .eq("dispatch_token", dispatchToken)
      .maybeSingle();
    if (runError) throw runError;
    if (!run) return response({ error: "Запуск не найден" }, 404);
    if (run.status === "sent") {
      return response({ ok: true, already_sent: true });
    }

    const { data: settings, error: settingsError } = await client
      .from("dispatcher_summary_settings")
      .select("*")
      .eq("company_id", run.company_id)
      .single();
    if (settingsError) throw settingsError;

    const { data: company, error: companyError } = await client
      .from("companies")
      .select("name")
      .eq("id", run.company_id)
      .single();
    if (companyError) throw companyError;

    const summaryDate = text(run.summary_date, 10);
    const date = new Date(`${summaryDate}T12:00:00Z`);
    const month = date.getUTCMonth() + 1;
    const year = date.getUTCFullYear();
    const startIso = `${summaryDate}T00:00:00Z`;
    const endDate = new Date(date.getTime() + 86400000)
      .toISOString()
      .slice(0, 10);
    const endIso = `${endDate}T00:00:00Z`;

    const payload: Record<string, unknown> = {
      company: company.name,
      date: summaryDate,
      generated_at: new Date().toISOString(),
    };
    const sections: string[] = [];
    let criticalCount = 0;

    if (settings.include_tasks) {
      const { data, error } = await client
        .from("tasks")
        .select("status,not_done_comment,is_draft")
        .eq("company_id", run.company_id)
        .eq("task_date", summaryDate);
      if (error) throw error;

      const rows = (data ?? []).filter((row: any) => row.is_draft !== true);
      const done = rows.filter((row: any) => row.status === "Выполнено").length;
      const pending = rows.length - done;
      const blocked = rows.filter(
        (row: any) => text(row.not_done_comment).length > 0,
      ).length;
      payload.tasks = { total: rows.length, done, pending, blocked };
      criticalCount += blocked;
      if (rows.length || settings.include_empty_sections) {
        sections.push(
          `Задачи: ${done} выполнено из ${rows.length}, незакрыто ${pending}, с проблемой ${blocked}.`,
        );
      }
    }

    if (settings.include_attendance || settings.include_employees) {
      const [employeeResult, attendanceResult] = await Promise.all([
        client
          .from("employees")
          .select("id,created_at,is_active,archived_at")
          .eq("company_id", run.company_id),
        client
          .from("attendance")
          .select("employee_id,shifts")
          .eq("company_id", run.company_id)
          .eq("work_date", summaryDate),
      ]);
      if (employeeResult.error) throw employeeResult.error;
      if (attendanceResult.error) throw attendanceResult.error;

      const employees = (employeeResult.data ?? []).filter(
        (row: any) => row.is_active === true && !row.archived_at,
      );
      const attendance = attendanceResult.data ?? [];
      const marked = new Set(
        attendance.map((row: any) => String(row.employee_id)),
      );
      const missing = employees.filter(
        (row: any) => !marked.has(String(row.id)),
      ).length;
      const totalShifts = attendance.reduce(
        (sum: number, row: any) => sum + numberValue(row.shifts),
        0,
      );
      const newEmployees = employees.filter(
        (row: any) =>
          String(row.created_at ?? "") >= startIso &&
          String(row.created_at ?? "") < endIso,
      ).length;

      payload.attendance = {
        active_employees: employees.length,
        marked: attendance.length,
        missing,
        total_shifts: totalShifts,
      };
      payload.employees = {
        active: employees.length,
        added_today: newEmployees,
      };
      criticalCount += missing;

      if (
        settings.include_attendance &&
        (employees.length || settings.include_empty_sections)
      ) {
        sections.push(
          `Табель: отмечено ${attendance.length} из ${employees.length}, без отметки ${missing}, смен ${totalShifts.toFixed(1)}.`,
        );
      }
      if (
        settings.include_employees &&
        (employees.length || settings.include_empty_sections)
      ) {
        sections.push(
          `Сотрудники: активных ${employees.length}, добавлено сегодня ${newEmployees}.`,
        );
      }
    }

    if (settings.include_payments) {
      const { data: payments, error } = await client
        .from("payments")
        .select("id,amount,payment_date")
        .eq("company_id", run.company_id)
        .eq("period_year", year)
        .eq("period_month", month);
      if (error) throw error;

      const paymentRows = payments ?? [];
      const paymentIds = paymentRows.map((row: any) => row.id);
      let receiptIds = new Set<string>();
      if (paymentIds.length) {
        const { data: receipts, error: receiptError } = await client
          .from("payment_receipts")
          .select("payment_id")
          .eq("company_id", run.company_id)
          .in("payment_id", paymentIds);
        if (receiptError) throw receiptError;
        receiptIds = new Set(
          (receipts ?? []).map((row: any) => String(row.payment_id)),
        );
      }

      const monthAmount = paymentRows.reduce(
        (sum: number, row: any) => sum + numberValue(row.amount),
        0,
      );
      const todayRows = paymentRows.filter(
        (row: any) => row.payment_date === summaryDate,
      );
      const missingReceipts = paymentRows.filter(
        (row: any) => !receiptIds.has(String(row.id)),
      ).length;

      payload.payments = {
        month_operations: paymentRows.length,
        month_amount: monthAmount,
        today_operations: todayRows.length,
        missing_receipts: missingReceipts,
      };
      criticalCount += missingReceipts;
      if (paymentRows.length || settings.include_empty_sections) {
        sections.push(
          `Выплаты: за месяц ${paymentRows.length} операций на ${monthAmount.toFixed(0)} ₽, сегодня ${todayRows.length}, без чека ${missingReceipts}.`,
        );
      }
    }

    if (settings.include_recruitment) {
      const { data: applications, error } = await client
        .from("recruitment_applications")
        .select("id,status,created_at,archived_at")
        .eq("company_id", run.company_id);
      if (error) throw error;

      const rows = (applications ?? []).filter(
        (row: any) => !row.archived_at,
      );
      const active = rows.filter(
        (row: any) =>
          !["Принят", "Отказ", "Отклонён", "Архив"].includes(
            text(row.status, 80),
          ),
      ).length;
      const newToday = rows.filter(
        (row: any) =>
          String(row.created_at ?? "") >= startIso &&
          String(row.created_at ?? "") < endIso,
      ).length;

      const { count: incomingToday, error: messageError } = await client
        .from("recruitment_messages")
        .select("id", { count: "exact", head: true })
        .eq("company_id", run.company_id)
        .eq("direction", "incoming")
        .gte("created_at", startIso)
        .lt("created_at", endIso);
      if (messageError) throw messageError;

      payload.recruitment = {
        active,
        new_today: newToday,
        incoming_messages_today: incomingToday ?? 0,
      };
      if (rows.length || settings.include_empty_sections) {
        sections.push(
          `Подбор: активных кандидатов ${active}, новых ${newToday}, входящих сообщений ${incomingToday ?? 0}.`,
        );
      }
    }

    if (settings.include_legal) {
      const [matterResult, documentResult] = await Promise.all([
        client
          .from("legal_matters")
          .select("status,due_at,risk_level,resolved_at")
          .eq("company_id", run.company_id),
        client
          .from("legal_documents")
          .select("expires_on,approval_status,archived_at")
          .eq("company_id", run.company_id),
      ]);
      if (matterResult.error) throw matterResult.error;
      if (documentResult.error) throw documentResult.error;

      const matters = (matterResult.data ?? []).filter(
        (row: any) =>
          !row.resolved_at &&
          !["Закрыт", "Решён"].includes(text(row.status, 80)),
      );
      const overdue = matters.filter(
        (row: any) => row.due_at && String(row.due_at) < startIso,
      ).length;
      const highRisk = matters.filter(
        (row: any) =>
          ["Высокий", "Критический", "high", "critical"].includes(
            text(row.risk_level, 80),
          ),
      ).length;
      const weekEnd = new Date(date.getTime() + 7 * 86400000)
        .toISOString()
        .slice(0, 10);
      const expiring = (documentResult.data ?? []).filter(
        (row: any) =>
          !row.archived_at &&
          row.expires_on &&
          row.expires_on >= summaryDate &&
          row.expires_on <= weekEnd,
      ).length;

      payload.legal = {
        open_matters: matters.length,
        overdue,
        high_risk: highRisk,
        expiring_documents_7d: expiring,
      };
      criticalCount += overdue + highRisk;
      if (matters.length || expiring || settings.include_empty_sections) {
        sections.push(
          `Юридическое: открыто ${matters.length}, просрочено ${overdue}, высокий риск ${highRisk}, истекает документов за 7 дней ${expiring}.`,
        );
      }
    }

    if (settings.include_milestones) {
      const { data, error } = await client
        .from("project_milestones")
        .select("status,target_date")
        .eq("company_id", run.company_id);
      if (error) throw error;

      const rows = (data ?? []).filter(
        (row: any) =>
          !["Выполнено", "Закрыто"].includes(text(row.status, 80)),
      );
      const overdue = rows.filter(
        (row: any) => row.target_date && row.target_date < summaryDate,
      ).length;
      const weekEnd = new Date(date.getTime() + 7 * 86400000)
        .toISOString()
        .slice(0, 10);
      const upcoming = rows.filter(
        (row: any) =>
          row.target_date &&
          row.target_date >= summaryDate &&
          row.target_date <= weekEnd,
      ).length;

      payload.milestones = {
        open: rows.length,
        overdue,
        upcoming_7d: upcoming,
      };
      criticalCount += overdue;
      if (rows.length || settings.include_empty_sections) {
        sections.push(
          `Цели и этапы: открыто ${rows.length}, просрочено ${overdue}, срок в ближайшие 7 дней у ${upcoming}.`,
        );
      }
    }

    payload.critical_count = criticalCount;
    const title =
      `Сводка ИИ-диспетчера · ${formatDateRu(summaryDate)}`;
    const generated = settings.ai_commentary
      ? await aiCommentary(payload)
      : "";
    const fallback = [
      `${company.name}. Итог за ${formatDateRu(summaryDate)}.`,
      ...sections,
      criticalCount > 0
        ? `Требует внимания: ${criticalCount} отклонений. Открой соответствующие разделы и назначь ответственных.`
        : "Критичных отклонений по выбранным разделам не найдено.",
    ].join("\n\n");
    const body = generated || fallback;

    const roles = Array.from(
      new Set(
        (settings.recipient_roles ?? ["admin"]).map(
          (role: unknown) => text(role, 30),
        ),
      ),
    );
    const notificationRows = roles.map((role) => ({
      company_id: run.company_id,
      title,
      body,
      actor_user_id: null,
      actor_name: "ИИ-диспетчер AppСтрой",
      actor_email: "",
      object_name: "",
      entity_type: "dispatcher_summary",
      entity_id: run.id,
      target_user_id: null,
      target_role: role,
      source_role: "admin",
      requires_action: criticalCount > 0,
      due_at: null,
      priority: criticalCount > 0 ? "high" : "normal",
      is_push_only: settings.in_app_enabled !== true,
      push_requested: settings.push_enabled === true,
    }));

    if (notificationRows.length) {
      const { error: notificationError } = await client
        .from("app_notifications")
        .insert(notificationRows);
      if (notificationError) throw notificationError;
    }

    const { error: updateError } = await client
      .from("dispatcher_summary_runs")
      .update({
        status: "sent",
        title,
        body,
        payload,
        ai_used: generated.length > 0,
        error_text: "",
        sent_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", run.id);
    if (updateError) throw updateError;

    return response({
      ok: true,
      run_id: run.id,
      ai_used: generated.length > 0,
      critical_count: criticalCount,
    });
  } catch (error) {
    console.error(error);
    if (runId) {
      await client
        .from("dispatcher_summary_runs")
        .update({
          status: "failed",
          error_text: error instanceof Error ? error.message : String(error),
          next_attempt_at: new Date(Date.now() + 15 * 60 * 1000)
            .toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", runId);
    }
    return response(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
