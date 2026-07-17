import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const foremanAllowedEntityTypes = new Set([
  "attendance",
  "tasks",
  "task_assignees",
  "task_photos",
  "legal_document",
  "legal_matter",
]);

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

interface NotificationRow {
  id: string;
  company_id: string;
  title: string;
  body: string;
  actor_user_id: string | null;
  object_name: string;
  entity_type: string;
  entity_id: string;
  target_user_id: string | null;
  target_role: string | null;
}

interface TokenRow {
  id: string;
  user_id: string;
  token: string;
  platform: "android" | "ios" | "web";
}

interface JobRow {
  id: string;
  notification_id: string;
  dispatch_token: string;
  status: string;
  attempts: number;
  updated_at: string;
}

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

function clean(value: unknown) {
  return String(value ?? "").trim();
}

function serviceKey(): string {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, string>;
      return parsed.default ?? Object.values(parsed)[0] ?? "";
    } catch (_) {
      // Fall back to the legacy service-role environment variable.
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

function base64Url(input: Uint8Array | string) {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function pemToArrayBuffer(pem: string) {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

async function createServiceAccountJwt(account: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: account.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64Url(new Uint8Array(signature))}`;
}

async function getGoogleAccessToken(account: ServiceAccount) {
  const assertion = await createServiceAccountJwt(account);
  const response = await fetch(
    account.token_uri ?? "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );
  const payload = await response.json();
  if (!response.ok || !payload.access_token) {
    throw new Error(
      `Не удалось получить Google access token: ${JSON.stringify(payload)}`,
    );
  }
  return String(payload.access_token);
}

function normalize(value: unknown) {
  return String(value ?? "").trim().toLocaleLowerCase("ru");
}

function fcmErrorCode(payload: unknown) {
  if (!payload || typeof payload !== "object") return "";
  const error = (payload as Record<string, unknown>).error;
  if (!error || typeof error !== "object") return "";
  const details = (error as Record<string, unknown>).details;
  if (!Array.isArray(details)) return "";
  for (const detail of details) {
    if (!detail || typeof detail !== "object") continue;
    const code = (detail as Record<string, unknown>).errorCode;
    if (typeof code === "string" && code) return code;
  }
  return "";
}

async function sendToToken(
  accessToken: string,
  account: ServiceAccount,
  notification: NotificationRow,
  token: TokenRow,
) {
  const publicUrl = Deno.env.get("APP_PUBLIC_URL") ??
    "https://13off.github.io/appstroy-web/";
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({
        message: {
          token: token.token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: {
            notification_id: notification.id,
            company_id: notification.company_id,
            object_name: notification.object_name ?? "",
            entity_type: notification.entity_type ?? "",
            entity_id: notification.entity_id ?? "",
          },
          android: {
            priority: "high",
            notification: {
              channel_id: "appstroy_updates",
              sound: "default",
            },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: { sound: "default", "content-available": 1 },
            },
          },
          webpush: {
            headers: { Urgency: "high" },
            notification: {
              icon: `${publicUrl.replace(/\/$/, "")}/icons/AppStroy-192-v2.png`,
              badge: `${publicUrl.replace(/\/$/, "")}/icons/AppStroy-192-v2.png`,
            },
            fcm_options: { link: publicUrl },
          },
        },
      }),
    },
  );
  const body = await response.json().catch(() => ({}));
  return {
    ok: response.ok,
    status: response.status,
    errorCode: fcmErrorCode(body),
  };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Метод не поддерживается" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = serviceKey();
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Push-сервис Supabase не настроен" }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let job: JobRow | null = null;
  try {
    const input = await request.json().catch(() => ({}));
    const jobId = clean(input.job_id);
    const dispatchToken = clean(input.dispatch_token);
    if (!jobId || !dispatchToken) {
      return json({ error: "Некорректная очередь push" }, 400);
    }

    const { data: rawJob, error: jobError } = await admin
      .from("push_notification_jobs")
      .select("id,notification_id,dispatch_token,status,attempts,updated_at")
      .eq("id", jobId)
      .eq("dispatch_token", dispatchToken)
      .maybeSingle();
    if (jobError) throw jobError;
    if (!rawJob) return json({ error: "Задание push не найдено" }, 404);
    job = rawJob as JobRow;

    const finalStatuses = new Set(["sent", "partial", "no_recipients"]);
    if (finalStatuses.has(job.status)) {
      return json({ ok: true, duplicate: true, status: job.status });
    }
    if (job.status === "processing") {
      const updatedAt = Date.parse(job.updated_at);
      if (Number.isFinite(updatedAt) && Date.now() - updatedAt < 5 * 60 * 1000) {
        return json({ ok: true, duplicate: true, status: "processing" }, 202);
      }
    }

    const now = new Date().toISOString();
    const { data: claimed, error: claimError } = await admin
      .from("push_notification_jobs")
      .update({
        status: "processing",
        attempts: Number(job.attempts ?? 0) + 1,
        last_error: "",
        updated_at: now,
      })
      .eq("id", job.id)
      .eq("dispatch_token", dispatchToken)
      .select("id")
      .maybeSingle();
    if (claimError) throw claimError;
    if (!claimed) {
      return json({ ok: true, duplicate: true, status: "processing" }, 202);
    }

    const { data: rawNotification, error: notificationError } = await admin
      .from("app_notifications")
      .select(
        "id,company_id,title,body,actor_user_id,object_name,entity_type,entity_id,target_user_id,target_role",
      )
      .eq("id", job.notification_id)
      .maybeSingle();
    if (notificationError) throw notificationError;
    if (!rawNotification) {
      await admin.from("push_notification_jobs").update({
        status: "failed",
        last_error: "Уведомление не найдено",
        updated_at: new Date().toISOString(),
      }).eq("id", job.id);
      return json({ error: "Уведомление не найдено" }, 404);
    }
    const notification = rawNotification as NotificationRow;

    const { data: existingDelivery, error: existingError } = await admin
      .from("push_notification_deliveries")
      .select("status,attempted_at")
      .eq("notification_id", notification.id)
      .maybeSingle();
    if (existingError) throw existingError;
    if (existingDelivery && finalStatuses.has(String(existingDelivery.status))) {
      await admin.from("push_notification_jobs").update({
        status: String(existingDelivery.status),
        updated_at: new Date().toISOString(),
      }).eq("id", job.id);
      return json({
        ok: true,
        duplicate: true,
        status: existingDelivery.status,
      });
    }
    if (existingDelivery) {
      const attemptedAt = Date.parse(String(existingDelivery.attempted_at));
      if (
        existingDelivery.status === "processing" &&
        Number.isFinite(attemptedAt) &&
        Date.now() - attemptedAt < 5 * 60 * 1000
      ) {
        return json({ ok: true, duplicate: true, status: "processing" }, 202);
      }
      await admin.from("push_notification_deliveries")
        .delete().eq("notification_id", notification.id);
    }

    let membershipsQuery = admin
      .from("company_memberships")
      .select("user_id,role")
      .eq("company_id", notification.company_id)
      .eq("is_active", true);
    if (notification.actor_user_id) {
      membershipsQuery = membershipsQuery.neq(
        "user_id",
        notification.actor_user_id,
      );
    }
    const { data: memberships, error: membershipsError } =
      await membershipsQuery;
    if (membershipsError) throw membershipsError;

    const recipientIds = new Set<string>();
    const foremanIds: string[] = [];
    for (const membership of memberships ?? []) {
      const userId = String(membership.user_id);
      const role = String(membership.role);
      if (role === "foreman") foremanIds.push(userId);

      if (notification.target_user_id === userId) {
        recipientIds.add(userId);
        continue;
      }
      if (notification.target_role) {
        const normalizedRole = role === "owner" ? "admin" : role;
        if (normalizedRole === notification.target_role) recipientIds.add(userId);
        continue;
      }
      if (role === "owner" || role === "admin") recipientIds.add(userId);
      if (role === "lawyer" && notification.entity_type.startsWith("legal_")) {
        recipientIds.add(userId);
      }
    }

    const targetForemen = notification.target_role === "foreman" ||
      (!notification.target_role && !notification.target_user_id);
    if (
      targetForemen &&
      foremanIds.length > 0 &&
      foremanAllowedEntityTypes.has(notification.entity_type) &&
      notification.object_name.trim()
    ) {
      const { data: objects, error: objectsError } = await admin
        .from("objects")
        .select("id,name")
        .eq("company_id", notification.company_id)
        .eq("is_active", true);
      if (objectsError) throw objectsError;
      const objectIds = (objects ?? [])
        .filter((row) => normalize(row.name) === normalize(notification.object_name))
        .map((row) => String(row.id));

      if (objectIds.length > 0) {
        const { data: assignments, error: assignmentsError } = await admin
          .from("object_memberships")
          .select("user_id")
          .eq("company_id", notification.company_id)
          .in("object_id", objectIds)
          .in("user_id", foremanIds);
        if (assignmentsError) throw assignmentsError;
        for (const assignment of assignments ?? []) {
          recipientIds.add(String(assignment.user_id));
        }
      }

      const { data: profiles, error: profilesError } = await admin
        .from("user_profiles")
        .select("id,object_name,is_active")
        .in("id", foremanIds)
        .eq("is_active", true);
      if (profilesError) throw profilesError;
      for (const profile of profiles ?? []) {
        if (normalize(profile.object_name) === normalize(notification.object_name)) {
          recipientIds.add(String(profile.id));
        }
      }
    }

    if (recipientIds.size === 0) {
      await admin.from("push_notification_deliveries").upsert({
        notification_id: notification.id,
        status: "no_recipients",
        completed_at: new Date().toISOString(),
        details: { reason: "role_and_object_filter" },
      }, { onConflict: "notification_id" });
      await admin.from("push_notification_jobs").update({
        status: "no_recipients",
        updated_at: new Date().toISOString(),
      }).eq("id", job.id);
      return json({ ok: true, status: "no_recipients", sent: 0 });
    }

    const { data: rawTokens, error: tokensError } = await admin
      .from("push_device_tokens")
      .select("id,user_id,token,platform")
      .eq("company_id", notification.company_id)
      .eq("enabled", true)
      .in("user_id", [...recipientIds]);
    if (tokensError) throw tokensError;
    const tokens = (rawTokens ?? []) as TokenRow[];

    if (tokens.length === 0) {
      await admin.from("push_notification_deliveries").upsert({
        notification_id: notification.id,
        status: "no_recipients",
        completed_at: new Date().toISOString(),
        details: { reason: "no_enabled_device_tokens" },
      }, { onConflict: "notification_id" });
      await admin.from("push_notification_jobs").update({
        status: "no_recipients",
        updated_at: new Date().toISOString(),
      }).eq("id", job.id);
      return json({ ok: true, status: "no_recipients", sent: 0 });
    }

    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJson) {
      const error =
        "Добавьте FIREBASE_SERVICE_ACCOUNT_JSON в Supabase Edge Function Secrets";
      await admin.from("push_notification_jobs").update({
        status: "failed",
        last_error: error,
        next_attempt_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", job.id);
      return json({
        ok: false,
        configured: false,
        skipped: true,
        error,
      }, 202);
    }
    const account = JSON.parse(serviceAccountJson) as ServiceAccount;
    if (!account.project_id || !account.client_email || !account.private_key) {
      throw new Error("Некорректный FIREBASE_SERVICE_ACCOUNT_JSON");
    }

    await admin.from("push_notification_deliveries").upsert({
      notification_id: notification.id,
      status: "processing",
      attempted_at: new Date().toISOString(),
      completed_at: null,
      sent_count: 0,
      failure_count: 0,
      details: { device_count: tokens.length },
    }, { onConflict: "notification_id" });

    const accessToken = await getGoogleAccessToken(account);
    let sentCount = 0;
    let failureCount = 0;
    const disabledTokenIds: string[] = [];
    const failureCodes: Record<string, number> = {};

    for (const token of tokens) {
      const result = await sendToToken(
        accessToken,
        account,
        notification,
        token,
      );
      if (result.ok) {
        sentCount += 1;
        continue;
      }
      failureCount += 1;
      const code = result.errorCode || `HTTP_${result.status}`;
      failureCodes[code] = (failureCodes[code] ?? 0) + 1;
      if (result.errorCode === "UNREGISTERED") disabledTokenIds.push(token.id);
    }

    if (disabledTokenIds.length > 0) {
      await admin.from("push_device_tokens")
        .update({ enabled: false, updated_at: new Date().toISOString() })
        .in("id", disabledTokenIds);
    }

    const status = sentCount === 0
      ? "failed"
      : failureCount === 0
      ? "sent"
      : "partial";
    await admin.from("push_notification_deliveries").update({
      status,
      completed_at: new Date().toISOString(),
      sent_count: sentCount,
      failure_count: failureCount,
      details: {
        device_count: tokens.length,
        disabled_token_count: disabledTokenIds.length,
        failure_codes: failureCodes,
      },
    }).eq("notification_id", notification.id);
    await admin.from("push_notification_jobs").update({
      status,
      last_error: sentCount === 0 ? JSON.stringify(failureCodes) : "",
      next_attempt_at: sentCount === 0
        ? new Date(Date.now() + 60 * 60 * 1000).toISOString()
        : null,
      updated_at: new Date().toISOString(),
    }).eq("id", job.id);

    return json({
      ok: sentCount > 0,
      status,
      sent: sentCount,
      failed: failureCount,
      disabled: disabledTokenIds.length,
    }, sentCount > 0 ? 200 : 502);
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    if (job) {
      await admin.from("push_notification_jobs").update({
        status: "failed",
        last_error: message || "Не удалось отправить push",
        next_attempt_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", job.id);
    }
    return json({ error: message || "Не удалось отправить push" }, 500);
  }
});
