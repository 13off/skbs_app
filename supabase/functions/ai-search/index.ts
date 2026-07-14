import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { searchAdmin } from "./admin_search.ts";
import { searchCore, SearchFlags } from "./core_search.ts";
import { parsePeriod } from "./period.ts";
import {
  bestMatches,
  clean,
  corsHeaders,
  findEmployees,
  json,
  norm,
  queryTokens,
} from "./shared.ts";

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Метод не поддерживается" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    const authorization = request.headers.get("Authorization") ?? "";
    if (!url || !anon || !authorization) return json({ error: "Сервис поиска не настроен" }, 500);

    const client = createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await client.auth.getUser();
    if (authError || !authData.user) return json({ error: "Требуется повторный вход" }, 401);

    const input = await request.json().catch(() => ({}));
    const companyId = clean(input.company_id, 80);
    const requestedObject = clean(input.object_name, 180);
    const prompt = clean(input.prompt, 4000);
    const workDate = /^\d{4}-\d{2}-\d{2}$/.test(clean(input.date, 10))
      ? clean(input.date, 10)
      : new Date().toISOString().slice(0, 10);
    if (!companyId) return json({ error: "Не выбрана активная компания" }, 400);
    if (!prompt) return json({ error: "Напиши, что нужно найти" }, 400);

    const { data: profile, error: profileError } = await client
      .from("user_profiles")
      .select("id, role, object_name, active_company_id, is_active")
      .eq("id", authData.user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.is_active !== true) return json({ error: "Профиль недоступен" }, 403);
    if (clean(profile.active_company_id, 80) !== companyId) {
      return json({ error: "Поиск работает только с активной компанией" }, 403);
    }

    const { data: membership, error: membershipError } = await client
      .from("company_memberships")
      .select("role, is_active")
      .eq("company_id", companyId)
      .eq("user_id", authData.user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return json({ error: "Нет доступа к компании" }, 403);

    const membershipRole = clean(membership.role, 30);
    const isAdmin = membershipRole === "admin" || membershipRole === "owner" || clean(profile.role, 30) === "admin";
    const assignedObject = clean(profile.object_name, 180);
    if (!isAdmin && !assignedObject) return json({ error: "Прорабу не назначен объект" }, 403);

    let objectsQuery: any = client
      .from("objects")
      .select("id, name, address, comment, is_active")
      .eq("company_id", companyId)
      .order("name");
    if (!isAdmin) objectsQuery = objectsQuery.eq("name", assignedObject);
    const { data: objectData, error: objectError } = await objectsQuery;
    if (objectError) throw objectError;
    const objects = objectData ?? [];
    if (requestedObject && !objects.some((item: any) => clean(item.name) === requestedObject)) {
      return json({ error: "Объект недоступен" }, 403);
    }

    const objectMatches = requestedObject
      ? []
      : bestMatches(objects, prompt, (item: any) => [item.name, item.address]);
    const promptObject = objectMatches.length === 1 ? clean(objectMatches[0].name, 180) : "";
    const objectName = isAdmin ? requestedObject || promptObject : assignedObject;

    let employeesQuery: any = client
      .from("employees")
      .select("id, fio, position, object_name, comment, is_active, archived_at")
      .eq("company_id", companyId)
      .order("fio");
    if (objectName) employeesQuery = employeesQuery.eq("object_name", objectName);
    const { data: employeeData, error: employeeError } = await employeesQuery;
    if (employeeError) throw employeeError;
    const employees = employeeData ?? [];

    const normalized = norm(prompt);
    const tokens = queryTokens(prompt);
    const period = parsePeriod(prompt, workDate);
    const matched = findEmployees(prompt, employees);
    const comments = /комментар|заметк|примечан/.test(normalized);
    const flags: SearchFlags = {
      employees: /сотрудник|работник|бетонщик|арматурщик|мастер|прораб|архивн|уволен|должност|кто работает|где работает/.test(normalized) || matched.length > 0,
      objects: /объект|адрес|площадк/.test(normalized),
      tasks: /задач|оси|невыполн|выполнен|просроч|работ(?:ы|у|а)\b/.test(normalized),
      attendance: /табел|смен|выход|отработ/.test(normalized),
      payments: /выплат|аванс|зарплат|оплат|перевод|начисл|деньг/.test(normalized),
      receipts: /чек|квитанц|подтвержден.*выплат/.test(normalized),
      users: /админ|прораб|пользовател|участник|доступ/.test(normalized),
      company: /компан|тариф|лимит|подписк|биллинг/.test(normalized),
      invitations: /приглаш|инвайт/.test(normalized),
      broad: false,
    };
    flags.broad = comments || !(
      flags.employees || flags.objects || flags.tasks || flags.attendance ||
      flags.payments || flags.receipts || flags.users || flags.company || flags.invitations
    );

    const core = await searchCore({
      client,
      companyId,
      objectName,
      prompt,
      normalized,
      tokens,
      period,
      employees,
      objects,
      flags,
    });
    const admin = await searchAdmin({
      client,
      companyId,
      objectName,
      tokens,
      normalized,
      period,
      employees,
      objects,
      matchedEmployee: matched.length === 1 ? matched[0] : null,
      flags,
      isAdmin,
    });

    const sections = [...core.sections, ...admin.sections];
    const highlights = [...core.highlights, ...admin.highlights];
    const warnings = [...core.warnings, ...admin.warnings];
    if (sections.length === 0) {
      return json({
        ok: true,
        mode: "universal_search",
        title: "Ничего не найдено",
        summary: "Уточни фамилию, объект, дату, статус, сумму или фразу из комментария.",
        highlights: [],
        warnings,
        next_steps: ["Примеры: «Где работает Филимонов?», «Невыполненные задачи в Мурманске», «Выплаты Филимонову за июнь», «Найди комментарий про бетон»."],
        scope: { object_name: objectName || "Все доступные объекты", date: period.explicit ? period.label : "без ограничения" },
        preliminary: true,
        ai_used: false,
      });
    }

    return json({
      ok: true,
      mode: "universal_search",
      title: "Результаты поиска",
      summary: sections.join("\n\n"),
      highlights,
      warnings,
      next_steps: ["Можно уточнить сотрудника, объект, статус или период следующим сообщением."],
      scope: { object_name: objectName || "Все доступные объекты", date: period.explicit ? period.label : "без ограничения периода" },
      preliminary: true,
      ai_used: false,
    });
  } catch (error) {
    console.error(error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
