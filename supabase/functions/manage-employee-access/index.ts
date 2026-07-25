import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type User } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

function normalizePhone(value: unknown) {
  const digits = String(value ?? "").replace(/\D/g, "");
  if (digits.length === 11 && (digits.startsWith("7") || digits.startsWith("8"))) {
    return `+7${digits.slice(1)}`;
  }
  if (digits.length === 10) return `+7${digits}`;
  if (digits.length >= 8 && digits.length <= 15) return `+${digits}`;
  return "";
}

async function findUserByPhone(
  adminClient: ReturnType<typeof createClient>,
  phone: string,
): Promise<User | null> {
  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await adminClient.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw error;
    const match = data.users.find(
      (candidate) => normalizePhone(candidate.phone) === phone,
    );
    if (match) return match;
    if (data.users.length < 1000) return null;
  }
  throw new Error("Слишком много пользователей для поиска по номеру");
}

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
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
      return json({ error: "Сервис доступа сотрудников не настроен" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user: actor },
      error: actorError,
    } = await userClient.auth.getUser();
    if (actorError || !actor) {
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const input = await request.json();
    const action = String(input.action ?? "status").trim();
    const employeeId = String(input.employee_id ?? "").trim();
    if (!employeeId) {
      return json({ error: "Не выбран сотрудник" }, 400);
    }
    if (!new Set(["status", "enable", "disable"]).has(action)) {
      return json({ error: "Неизвестное действие" }, 400);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: employee, error: employeeError } = await adminClient
      .from("employees")
      .select(
        "id, company_id, person_id, object_id, object_name, fio, position, phone, is_active, archived_at",
      )
      .eq("id", employeeId)
      .single();
    if (employeeError) throw employeeError;

    const companyId = String(employee.company_id ?? "").trim();
    const personId = String(employee.person_id ?? "").trim();
    if (!companyId || !personId) {
      return json({ error: "Карточка сотрудника не связана с человеком" }, 409);
    }

    const { data: actorMembership, error: membershipError } = await adminClient
      .from("company_memberships")
      .select("role, is_active")
      .eq("company_id", companyId)
      .eq("user_id", actor.id)
      .in("role", ["owner", "admin", "developer"])
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!actorMembership) {
      return json(
        { error: "Управлять доступом может только руководитель или разработчик" },
        403,
      );
    }

    const { data: company, error: companyError } = await adminClient
      .from("companies")
      .select("id, status")
      .eq("id", companyId)
      .single();
    if (companyError) throw companyError;
    if (company.status !== "active") {
      return json({ error: "Компания временно отключена" }, 403);
    }

    const { data: currentLink, error: linkReadError } = await adminClient
      .from("employee_account_links")
      .select("company_id, person_id, user_id, phone_e164, is_active, updated_at")
      .eq("company_id", companyId)
      .eq("person_id", personId)
      .maybeSingle();
    if (linkReadError) throw linkReadError;

    if (action === "status") {
      return json({
        ok: true,
        connected: currentLink !== null,
        active: currentLink?.is_active === true,
        phone: currentLink?.phone_e164 ?? normalizePhone(employee.phone),
      });
    }

    if (action === "disable") {
      if (!currentLink) {
        return json({ ok: true, connected: false, active: false });
      }

      const { error: disableError } = await adminClient
        .from("employee_account_links")
        .update({
          is_active: false,
          updated_at: new Date().toISOString(),
        })
        .eq("company_id", companyId)
        .eq("person_id", personId);
      if (disableError) throw disableError;

      const { data: anotherLink, error: anotherLinkError } = await adminClient
        .from("employee_account_links")
        .select("company_id")
        .eq("user_id", currentLink.user_id)
        .eq("is_active", true)
        .neq("company_id", companyId)
        .limit(1)
        .maybeSingle();
      if (anotherLinkError) throw anotherLinkError;

      const { error: profileDisableError } = await adminClient
        .from("user_profiles")
        .update({
          is_active: anotherLink !== null,
          active_company_id: anotherLink?.company_id ?? companyId,
          updated_at: new Date().toISOString(),
        })
        .eq("id", currentLink.user_id)
        .eq("role", "employee");
      if (profileDisableError) throw profileDisableError;

      return json({ ok: true, connected: true, active: false });
    }

    if (employee.archived_at != null || employee.is_active !== true) {
      return json({ error: "Сначала верните сотрудника в активные" }, 409);
    }

    const phone = normalizePhone(employee.phone);
    if (!phone) {
      return json(
        { error: "В карточке сотрудника укажите корректный номер телефона" },
        400,
      );
    }

    let employeeUser = await findUserByPhone(adminClient, phone);
    if (employeeUser) {
      const { data: existingProfile, error: existingProfileError } =
        await adminClient
          .from("user_profiles")
          .select("id, role, full_name, active_company_id")
          .eq("id", employeeUser.id)
          .maybeSingle();
      if (existingProfileError) throw existingProfileError;

      const { data: conflictingLink, error: conflictingLinkError } =
        await adminClient
          .from("employee_account_links")
          .select("person_id")
          .eq("company_id", companyId)
          .eq("user_id", employeeUser.id)
          .neq("person_id", personId)
          .maybeSingle();
      if (conflictingLinkError) throw conflictingLinkError;

      if (conflictingLink) {
        return json(
          { error: "Этот номер уже подключён к другому сотруднику компании" },
          409,
        );
      }
      if (
        existingProfile &&
        existingProfile.role !== "employee" &&
        currentLink?.user_id !== employeeUser.id
      ) {
        return json(
          {
            error:
              "Этот номер принадлежит руководителю или специалисту. Для сотрудника укажите другой номер",
          },
          409,
        );
      }
      if (
        String(employeeUser.email ?? "").trim() &&
        !existingProfile &&
        currentLink?.user_id !== employeeUser.id
      ) {
        return json(
          {
            error:
              "Этот номер уже используется корпоративным аккаунтом. Для сотрудника укажите другой номер",
          },
          409,
        );
      }
    } else {
      const { data: created, error: createError } =
        await adminClient.auth.admin.createUser({
          phone,
          phone_confirm: true,
          user_metadata: {
            full_name: String(employee.fio ?? "").trim(),
          },
          app_metadata: {
            role: "employee",
          },
        });
      if (createError) throw createError;
      employeeUser = created.user;
    }

    if (!employeeUser) {
      throw new Error("Не удалось создать аккаунт сотрудника");
    }

    const { data: updatedAuth, error: authUpdateError } =
      await adminClient.auth.admin.updateUserById(employeeUser.id, {
        phone,
        phone_confirm: true,
        user_metadata: {
          ...(employeeUser.user_metadata ?? {}),
          full_name: String(employee.fio ?? "").trim(),
        },
        app_metadata: {
          ...(employeeUser.app_metadata ?? {}),
          role: "employee",
        },
      });
    if (authUpdateError) throw authUpdateError;
    employeeUser = updatedAuth.user;

    const now = new Date().toISOString();
    const { error: profileWriteError } = await adminClient
      .from("user_profiles")
      .upsert(
        {
          id: employeeUser.id,
          email: employeeUser.email ?? null,
          full_name: String(employee.fio ?? "").trim() || "Сотрудник",
          phone,
          role: "employee",
          profession: String(employee.position ?? "").trim(),
          object_name: String(employee.object_name ?? "").trim(),
          is_active: true,
          active_company_id: companyId,
          updated_at: now,
        },
        { onConflict: "id" },
      );
    if (profileWriteError) throw profileWriteError;

    const { error: linkWriteError } = await adminClient
      .from("employee_account_links")
      .upsert(
        {
          company_id: companyId,
          person_id: personId,
          user_id: employeeUser.id,
          phone_e164: phone,
          is_active: true,
          created_by: actor.id,
          updated_at: now,
        },
        { onConflict: "company_id,person_id" },
      );
    if (linkWriteError) throw linkWriteError;

    return json({
      ok: true,
      connected: true,
      active: true,
      phone,
    });
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message || "Не удалось изменить доступ сотрудника" }, 500);
  }
});
