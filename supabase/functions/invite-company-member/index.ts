import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type User } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

function cleanEmail(value: unknown) {
  return String(value ?? "").trim().toLowerCase();
}

const defaultWebAppUrl = "https://13off.github.io/appstroy-web/";

function invitationRedirectUrl(companyId: string) {
  const url = new URL(defaultWebAppUrl);
  url.searchParams.set("companyInvite", companyId);
  return url.toString();
}

function invitationActionUrl(
  companyId: string,
  tokenHash: string,
  verificationType: string,
) {
  const url = new URL(defaultWebAppUrl);
  url.searchParams.set("companyInvite", companyId);
  url.searchParams.set("inviteTokenHash", tokenHash);
  url.searchParams.set("inviteType", verificationType);
  return url.toString();
}

async function findUserByEmail(
  adminClient: ReturnType<typeof createClient>,
  email: string,
): Promise<User | null> {
  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await adminClient.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw error;

    const match = data.users.find(
      (candidate) => cleanEmail(candidate.email) === email,
    );
    if (match) return match;
    if (data.users.length < 1000) return null;
  }

  throw new Error("Слишком много пользователей для поиска приглашения");
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
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authorization = request.headers.get("Authorization") ?? "";

    if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
      return json({ error: "Сервис приглашений не настроен" }, 500);
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
    const companyId = String(input.company_id ?? "").trim();
    const email = cleanEmail(input.email);
    const fullName = String(input.full_name ?? "").trim();
    const role = String(input.role ?? "foreman").trim();
    const objectId = String(input.object_id ?? "").trim();
    const redirectTo = invitationRedirectUrl(companyId);

    if (!companyId || !email || !email.includes("@")) {
      return json({ error: "Укажите компанию и корректный email" }, 400);
    }
    if (!fullName) {
      return json({ error: "Укажите имя пользователя" }, 400);
    }
    if (role !== "admin" && role !== "foreman") {
      return json({ error: "Недопустимая роль" }, 400);
    }
    if (role === "foreman" && !objectId) {
      return json({ error: "Для прораба выберите объект" }, 400);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: actorMembership, error: actorMembershipError } =
      await adminClient
        .from("company_memberships")
        .select("role, is_active")
        .eq("company_id", companyId)
        .eq("user_id", actor.id)
        .in("role", ["owner", "admin"])
        .eq("is_active", true)
        .maybeSingle();

    if (actorMembershipError) throw actorMembershipError;
    if (!actorMembership) {
      return json({ error: "Приглашать может только администратор компании" }, 403);
    }

    const { data: company, error: companyError } = await adminClient
      .from("companies")
      .select("id, name, status, seat_limit")
      .eq("id", companyId)
      .single();
    if (companyError) throw companyError;
    if (company.status !== "active") {
      return json({ error: "Компания временно отключена" }, 403);
    }

    let objectName: string | null = null;
    if (role === "foreman") {
      const { data: object, error: objectError } = await adminClient
        .from("objects")
        .select("id, name, is_active")
        .eq("id", objectId)
        .eq("company_id", companyId)
        .eq("is_active", true)
        .single();
      if (objectError) throw objectError;
      objectName = object.name;
    }

    let invitedUser = await findUserByEmail(adminClient, email);
    const existingUser = invitedUser !== null;
    const existingUserId = invitedUser?.id;
    const mustSetPasswordValue =
      invitedUser?.user_metadata?.must_set_password;
    const requiresPasswordSetup =
      existingUser &&
      (
        mustSetPasswordValue === true ||
        String(mustSetPasswordValue).toLowerCase() === "true"
      );

    let existingMembership: { user_id: string } | null = null;
    if (existingUserId) {
      const membershipResult = await adminClient
        .from("company_memberships")
        .select("user_id")
        .eq("company_id", companyId)
        .eq("user_id", existingUserId)
        .eq("is_active", true)
        .maybeSingle();
      if (membershipResult.error) throw membershipResult.error;
      existingMembership = membershipResult.data;
    }

    if (!existingMembership) {
      const membershipCountResult = await adminClient
        .from("company_memberships")
        .select("user_id", { count: "exact", head: true })
        .eq("company_id", companyId)
        .eq("is_active", true);
      if (membershipCountResult.error) throw membershipCountResult.error;
      if ((membershipCountResult.count ?? 0) >= Number(company.seat_limit)) {
        return json({ error: "Достигнут лимит пользователей тарифа" }, 409);
      }
    }

    let actionLink = "";
    let delivery = "invite_link";

    if (!invitedUser) {
      const { data: linkData, error: linkError } =
        await adminClient.auth.admin.generateLink({
          type: "invite",
          email,
          options: {
            redirectTo,
            data: {
              full_name: fullName,
              invited_company_id: companyId,
              invited_company_name: company.name,
              must_set_password: true,
            },
          },
        });
      if (linkError) throw linkError;
      invitedUser = linkData.user;
      const tokenHash = linkData.properties?.hashed_token ?? "";
      const verificationType =
        linkData.properties?.verification_type ?? "invite";
      if (!tokenHash) {
        throw new Error("Supabase не вернул токен приглашения");
      }
      actionLink = invitationActionUrl(
        companyId,
        tokenHash,
        verificationType,
      );
      delivery = "invite_link";
    } else {
      const linkType = requiresPasswordSetup ? "recovery" : "magiclink";
      const { data: linkData, error: linkError } =
        await adminClient.auth.admin.generateLink({
          type: linkType,
          email,
          options: { redirectTo },
        });
      if (linkError) throw linkError;
      const tokenHash = linkData.properties?.hashed_token ?? "";
      const verificationType =
        linkData.properties?.verification_type ?? linkType;
      if (!tokenHash) {
        throw new Error("Supabase не вернул токен входа");
      }
      actionLink = invitationActionUrl(
        companyId,
        tokenHash,
        verificationType,
      );
      delivery = requiresPasswordSetup
        ? "password_setup_link"
        : "sign_in_link";
    }

    if (!actionLink) {
      throw new Error("Supabase не вернул ссылку приглашения");
    }

    if (!invitedUser) {
      throw new Error("Supabase не вернул приглашённого пользователя");
    }

    const { data: existingProfile, error: profileReadError } = await adminClient
      .from("user_profiles")
      .select("id, active_company_id, full_name")
      .eq("id", invitedUser.id)
      .maybeSingle();
    if (profileReadError) throw profileReadError;

    const { error: membershipWriteError } = await adminClient
      .from("company_memberships")
      .upsert(
        {
          company_id: companyId,
          user_id: invitedUser.id,
          role,
          is_active: true,
          invited_by: actor.id,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "company_id,user_id" },
      );
    if (membershipWriteError) throw membershipWriteError;

    if (!existingProfile) {
      const { error: profileInsertError } = await adminClient
        .from("user_profiles")
        .insert({
          id: invitedUser.id,
          email,
          full_name: fullName,
          role,
          object_name: objectName,
          is_active: true,
          active_company_id: companyId,
        });
      if (profileInsertError) throw profileInsertError;
    } else if (!existingProfile.active_company_id) {
      const { error: profileUpdateError } = await adminClient
        .from("user_profiles")
        .update({
          email,
          full_name: existingProfile.full_name || fullName,
          role,
          object_name: objectName,
          is_active: true,
          active_company_id: companyId,
          updated_at: new Date().toISOString(),
        })
        .eq("id", invitedUser.id);
      if (profileUpdateError) throw profileUpdateError;
    }

    const { error: clearAssignmentsError } = await adminClient
      .from("object_memberships")
      .delete()
      .eq("company_id", companyId)
      .eq("user_id", invitedUser.id);
    if (clearAssignmentsError) throw clearAssignmentsError;

    if (role === "foreman") {
      const { error: assignmentError } = await adminClient
        .from("object_memberships")
        .insert({
          company_id: companyId,
          object_id: objectId,
          user_id: invitedUser.id,
          created_by: actor.id,
        });
      if (assignmentError) throw assignmentError;
    }

    await adminClient
      .from("company_invitations")
      .update({ status: "revoked", updated_at: new Date().toISOString() })
      .eq("company_id", companyId)
      .eq("email", email)
      .eq("status", "pending");

    const { error: invitationLogError } = await adminClient
      .from("company_invitations")
      .insert({
        company_id: companyId,
        email,
        role,
        object_id: role === "foreman" ? objectId : null,
        invited_by: actor.id,
        invited_user_id: invitedUser.id,
        status: "pending",
        accepted_at: null,
      });
    if (invitationLogError) throw invitationLogError;

    return json({
      ok: true,
      user_id: invitedUser.id,
      existing_user: existingUser,
      delivery,
      invite_url: actionLink,
      redirect_to: redirectTo,
    });
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message || "Не удалось отправить приглашение" }, 500);
  }
});
