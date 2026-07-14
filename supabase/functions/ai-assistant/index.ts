import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const allowedModes = new Set([
  "timesheet_check",
  "site_summary",
  "document_draft",
  "chat",
]);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function cleanText(value: unknown, maxLength = 4000) {
  return String(value ?? "").trim().slice(0, maxLength);
}

function dateKey(value: unknown) {
  const candidate = cleanText(value, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(candidate)) return candidate;
  return new Date().toISOString().slice(0, 10);
}

function numberValue(value: unknown) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function stringList(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => cleanText(item, 600))
    .filter((item) => item.length > 0)
    .slice(0, 12);
}

function extractResponseText(payload: any) {
  if (typeof payload?.output_text === "string") {
    return payload.output_text.trim();
  }

  for (const item of payload?.output ?? []) {
    for (const content of item?.content ?? []) {
      if (content?.type === "output_text" && typeof content.text === "string") {
        return content.text.trim();
      }
    }
  }

  return "";
}

function parseModelResult(text: string) {
  const withoutFence = text
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();

  try {
    const parsed = JSON.parse(withoutFence);
    return {
      title: cleanText(parsed?.title, 140) || "Ответ ИИ-помощника",
      summary: cleanText(parsed?.summary, 6000),
      highlights: stringList(parsed?.highlights),
      warnings: stringList(parsed?.warnings),
      next_steps: stringList(parsed?.next_steps),
    };
  } catch (_) {
    return {
      title: "Ответ ИИ-помощника",
      summary: cleanText(text, 6000),
      highlights: [],
      warnings: [],
      next_steps: ["Проверь факты и формулировки перед использованием результата."],
    };
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Метод не поддерживается" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const authorization = request.headers.get("Authorization") ?? "";

    if (!supabaseUrl || !anonKey || !authorization) {
      return json({ error: "Сервис ИИ-помощника не настроен" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const input = await request.json().catch(() => ({}));
    const mode = cleanText(input.mode, 40) || "chat";
    const requestedCompanyId = cleanText(input.company_id, 80);
    const requestedObjectName = cleanText(input.object_name, 180);
    const prompt = cleanText(input.prompt, 4000);
    const workDate = dateKey(input.date);

    if (!allowedModes.has(mode)) {
      return json({ error: "Неподдерживаемый режим помощника" }, 400);
    }

    const { data: profile, error: profileError } = await userClient
      .from("user_profiles")
      .select("id, full_name, role, object_name, active_company_id, is_active")
      .eq("id", user.id)
      .maybeSingle();

    if (profileError) throw profileError;
    if (!profile || profile.is_active !== true) {
      return json({ error: "Профиль пользователя недоступен" }, 403);
    }

    const activeCompanyId = cleanText(profile.active_company_id, 80);
    if (!activeCompanyId || activeCompanyId !== requestedCompanyId) {
      return json({ error: "Помощник работает только с активной компанией" }, 403);
    }

    const { data: membership, error: membershipError } = await userClient
      .from("company_memberships")
      .select("role, is_active")
      .eq("company_id", activeCompanyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();

    if (membershipError) throw membershipError;
    if (!membership) {
      return json({ error: "Нет доступа к выбранной компании" }, 403);
    }

    const role = cleanText(profile.role, 30) === "admin" ? "admin" : "foreman";
    const assignedObjectName = cleanText(profile.object_name, 180);
    const effectiveObjectName = role === "foreman"
      ? assignedObjectName
      : requestedObjectName;

    if (role === "foreman" && !effectiveObjectName) {
      return json({ error: "Прорабу не назначен объект" }, 403);
    }

    if (effectiveObjectName) {
      const { data: object, error: objectError } = await userClient
        .from("objects")
        .select("id, name")
        .eq("company_id", activeCompanyId)
        .eq("name", effectiveObjectName)
        .eq("is_active", true)
        .maybeSingle();

      if (objectError) throw objectError;
      if (!object) {
        return json({ error: "Объект недоступен в активной компании" }, 403);
      }
    }

    let employeesQuery = userClient
      .from("employees")
      .select("id, fio, position, object_name")
      .eq("company_id", activeCompanyId)
      .eq("is_active", true)
      .is("archived_at", null)
      .order("fio", { ascending: true });
    let attendanceQuery = userClient
      .from("attendance")
      .select("employee_id, shifts, status, object_name")
      .eq("company_id", activeCompanyId)
      .eq("work_date", workDate);
    let tasksQuery = userClient
      .from("tasks")
      .select("id, status, work, axes, not_done_comment, object_name")
      .eq("company_id", activeCompanyId)
      .eq("task_date", workDate)
      .order("created_at", { ascending: true });

    if (effectiveObjectName) {
      employeesQuery = employeesQuery.eq("object_name", effectiveObjectName);
      attendanceQuery = attendanceQuery.eq("object_name", effectiveObjectName);
      tasksQuery = tasksQuery.eq("object_name", effectiveObjectName);
    }

    const [employeesResult, attendanceResult, tasksResult] = await Promise.all([
      employeesQuery,
      attendanceQuery,
      tasksQuery,
    ]);

    if (employeesResult.error) throw employeesResult.error;
    if (attendanceResult.error) throw attendanceResult.error;
    if (tasksResult.error) throw tasksResult.error;

    const employees = employeesResult.data ?? [];
    const attendance = attendanceResult.data ?? [];
    const tasks = tasksResult.data ?? [];
    const employeeById = new Map(
      employees.map((employee: any) => [String(employee.id), employee]),
    );
    const attendanceByEmployeeId = new Map(
      attendance.map((row: any) => [String(row.employee_id), row]),
    );
    const missingEmployees = employees.filter(
      (employee: any) => !attendanceByEmployeeId.has(String(employee.id)),
    );
    const elevatedShifts = attendance.filter(
      (row: any) => numberValue(row.shifts) > 2,
    );
    const workedRows = attendance.filter(
      (row: any) => numberValue(row.shifts) > 0,
    );
    const totalShifts = workedRows.reduce(
      (sum: number, row: any) => sum + numberValue(row.shifts),
      0,
    );
    const doneTasks = tasks.filter((task: any) => task.status === "Выполнено");
    const pendingTasks = tasks.filter((task: any) => task.status !== "Выполнено");
    const blockedTasks = tasks.filter(
      (task: any) => cleanText(task.not_done_comment, 500).length > 0,
    );
    const scope = {
      object_name: effectiveObjectName || "Все доступные объекты",
      date: workDate,
    };
    const modelReady = Boolean(
      cleanText(Deno.env.get("OPENAI_API_KEY"), 500) &&
        cleanText(Deno.env.get("OPENAI_MODEL"), 120),
    );

    if (mode === "timesheet_check") {
      const warnings: string[] = [];
      if (missingEmployees.length > 0) {
        const names = missingEmployees
          .slice(0, 10)
          .map((employee: any) => cleanText(employee.fio, 160))
          .filter(Boolean)
          .join(", ");
        warnings.push(
          `Нет строк табеля: ${missingEmployees.length}. ${names}${
            missingEmployees.length > 10 ? "…" : ""
          }`,
        );
      }
      if (elevatedShifts.length > 0) {
        const values = elevatedShifts
          .slice(0, 10)
          .map((row: any) => {
            const employee = employeeById.get(String(row.employee_id));
            return `${cleanText(employee?.fio, 160) || "Сотрудник"} — ${numberValue(row.shifts)}`;
          })
          .join(", ");
        warnings.push(`Повышенное количество смен, проверь вручную: ${values}`);
      }
      if (warnings.length === 0) {
        warnings.push("Явных пропусков и повышенных значений не найдено.");
      }

      return json({
        ok: true,
        mode,
        title: "Проверка табеля завершена",
        summary:
          `За ${workDate} найдено ${employees.length} активных сотрудников. ` +
          `Отмечено ${workedRows.length}, всего ${totalShifts.toFixed(1)} смен.`,
        highlights: [
          `Активных сотрудников: ${employees.length}`,
          `Строк табеля: ${attendance.length}`,
          `Отработали: ${workedRows.length}`,
          `Сумма смен: ${totalShifts.toFixed(1)}`,
        ],
        warnings,
        next_steps: [
          "Сверь предупреждения с прорабом или ответственным за табель.",
          "Исправления вноси вручную в разделе «Табель» после проверки.",
        ],
        scope,
        preliminary: true,
        ai_used: false,
        model_ready: modelReady,
      });
    }

    if (mode === "site_summary") {
      const warnings: string[] = [];
      if (missingEmployees.length > 0) {
        warnings.push(`У ${missingEmployees.length} сотрудников нет строки табеля.`);
      }
      if (pendingTasks.length > 0) {
        warnings.push(`Не завершено задач: ${pendingTasks.length}.`);
      }
      if (blockedTasks.length > 0) {
        warnings.push(`Есть комментарии о невыполнении у ${blockedTasks.length} задач.`);
      }
      if (warnings.length === 0) {
        warnings.push("По доступным данным критичных отклонений не найдено.");
      }

      return json({
        ok: true,
        mode,
        title: "Рабочая сводка за сегодня",
        summary:
          `Область: ${scope.object_name}. На ${workDate} в работе ${employees.length} сотрудников, ` +
          `${workedRows.length} отмечены в табеле. Выполнено ${doneTasks.length} из ${tasks.length} задач.`,
        highlights: [
          `Активных сотрудников: ${employees.length}`,
          `Отработали по табелю: ${workedRows.length}`,
          `Всего смен: ${totalShifts.toFixed(1)}`,
          `Задачи: ${doneTasks.length} выполнено, ${pendingTasks.length} остаётся`,
        ],
        warnings,
        next_steps: [
          "Проверь незавершённые задачи и комментарии исполнителей.",
          "Перед передачей сводки руководителю сверь цифры с первичными данными.",
        ],
        scope,
        preliminary: true,
        ai_used: false,
        model_ready: modelReady,
      });
    }

    const openAiKey = cleanText(Deno.env.get("OPENAI_API_KEY"), 500);
    const openAiModel = cleanText(Deno.env.get("OPENAI_MODEL"), 120);
    if (!openAiKey || !openAiModel) {
      return json(
        {
          error:
            "Проверка табеля и сводка уже работают. Для свободного диалога и черновиков добавь OPENAI_API_KEY и OPENAI_MODEL в секреты Supabase.",
          configuration_required: true,
        },
        503,
      );
    }
    if (!prompt) {
      return json({ error: "Напиши запрос для ИИ-помощника" }, 400);
    }

    const compactContext = {
      date: workDate,
      object_scope: scope.object_name,
      user_role: role,
      active_employees: employees.length,
      attendance_rows: attendance.length,
      worked_employees: workedRows.length,
      total_shifts: Number(totalShifts.toFixed(1)),
      missing_attendance_rows: missingEmployees.length,
      tasks_total: tasks.length,
      tasks_done: doneTasks.length,
      tasks_pending: pendingTasks.length,
      tasks_with_not_done_comment: blockedTasks.length,
    };
    const systemPrompt = [
      "Ты встроенный рабочий помощник строительной компании AppСтрой.",
      "Отвечай по-русски, конкретно и без выдуманных фактов.",
      "Результат всегда предварительный: человек обязан проверить его перед использованием.",
      "Не предлагай напрямую менять базу, увольнять людей, начислять деньги или принимать юридические решения.",
      "Для документов делай только черновик и помечай места, где не хватает фактов.",
      "Верни только JSON с полями title, summary, highlights, warnings, next_steps.",
      "highlights, warnings и next_steps должны быть массивами коротких строк.",
    ].join("\n");
    const userPrompt = JSON.stringify({
      mode,
      request: prompt,
      company_context: compactContext,
    });

    const modelResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: openAiModel,
        store: false,
        max_output_tokens: 1200,
        input: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
    });
    const modelPayload = await modelResponse.json().catch(() => ({}));
    if (!modelResponse.ok) {
      console.error("OpenAI response error", modelResponse.status, modelPayload);
      return json({ error: "ИИ-модель не ответила. Повтори запрос позже." }, 502);
    }

    const outputText = extractResponseText(modelPayload);
    if (!outputText) {
      return json({ error: "ИИ-модель вернула пустой результат" }, 502);
    }
    const parsed = parseModelResult(outputText);

    return json({
      ok: true,
      mode,
      ...parsed,
      scope,
      preliminary: true,
      ai_used: true,
      model_ready: true,
    });
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
