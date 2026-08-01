import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const COMPANY_ID = "e39c8fd5-e7f3-4beb-a269-76e893975a98";
const SOURCE = "max";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const EXPECTED_SECRET_SHA256 = "02a21c471455316906e01a00b60d0806b3dfcecefd6086b7e0b67921c9985648";

type JsonMap = Record<string, unknown>;
type ApplicationInput = {
  externalApplicationId?: string;
  maxUserId?: string;
  maxChatId?: string;
  maxUsername?: string | null;
  maxDisplayName?: string;
  fullName?: string;
  phone?: string;
  citizenship?: string;
  objectId?: string;
  vacancyId?: string;
  positionTitle?: string;
  experience?: string;
  readyText?: string;
  age?: number | string;
  comment?: string;
};
type RequestPayload = {
  action?: string;
  application?: ApplicationInput;
  applicationId?: string;
  externalApplicationId?: string;
  maxUserId?: string;
  maxChatId?: string;
  maxMessageId?: string;
  messageId?: string;
  text?: string;
  error?: string;
};

function serviceKey(): string {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, string>;
      return parsed.default ?? Object.values(parsed)[0] ?? "";
    } catch (_) {}
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

const admin = createClient(SUPABASE_URL, serviceKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});

function clean(value: unknown): string {
  return String(value ?? "").trim();
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json; charset=utf-8",
    },
  });
}

function normalizePhone(value: unknown): string {
  let digits = clean(value).replace(/\D/g, "");
  if (digits.length === 11 && digits.startsWith("8")) digits = `7${digits.slice(1)}`;
  if (digits.length === 10) digits = `7${digits}`;
  if (digits.length < 10 || digits.length > 15) return "";
  return `+${digits}`;
}

function parseReadyDate(value: unknown): string | null {
  const text = clean(value).toLowerCase();
  if (!text) return null;
  if (["сразу", "сейчас", "готов сразу", "готов сейчас"].includes(text)) {
    return new Date().toISOString().slice(0, 10);
  }
  const iso = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  const ru = text.match(/^(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{4})$/);
  let year = 0;
  let month = 0;
  let day = 0;
  if (iso) {
    year = Number(iso[1]); month = Number(iso[2]); day = Number(iso[3]);
  } else if (ru) {
    day = Number(ru[1]); month = Number(ru[2]); year = Number(ru[3]);
  } else {
    return null;
  }
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return date.toISOString().slice(0, 10);
}

function applicationNumber(id: string): string {
  return id.replaceAll("-", "").slice(-8).toUpperCase();
}

function relation(value: unknown): JsonMap {
  if (Array.isArray(value)) return (value[0] ?? {}) as JsonMap;
  if (value && typeof value === "object") return value as JsonMap;
  return {};
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

async function authorized(request: Request): Promise<boolean> {
  const received = clean(request.headers.get("x-appstroy-max-secret"));
  if (received.length < 24) return false;
  return constantTimeEqual(await sha256(received), EXPECTED_SECRET_SHA256);
}

async function notifyRoles(
  title: string,
  body: string,
  applicationId: string,
  objectName = "",
): Promise<void> {
  const rows = ["admin", "hr"].map((role) => ({
    company_id: COMPANY_ID,
    title,
    body,
    actor_name: "Кандидат",
    actor_email: "",
    object_name: objectName,
    entity_type: "recruitment_application",
    entity_id: applicationId,
    target_role: role,
    requires_action: true,
    priority: "high",
    source_role: "system",
    push_requested: true,
  }));
  const { error } = await admin.from("app_notifications").insert(rows);
  if (error) console.error("MAX notification failed", error);
}

async function catalog(): Promise<Response> {
  const [objectsResult, vacanciesResult] = await Promise.all([
    admin.from("objects")
      .select("id,name,address,comment")
      .eq("company_id", COMPANY_ID)
      .eq("is_active", true)
      .order("name"),
    admin.from("recruitment_vacancies")
      .select("id,object_id,title,salary_text,schedule_text,conditions_text,sort_order")
      .eq("company_id", COMPANY_ID)
      .eq("is_active", true)
      .order("sort_order")
      .order("title"),
  ]);
  if (objectsResult.error) throw objectsResult.error;
  if (vacanciesResult.error) throw vacanciesResult.error;

  const vacancies = (vacanciesResult.data ?? []) as JsonMap[];
  const objects = ((objectsResult.data ?? []) as JsonMap[]).map((object) => {
    const objectId = clean(object.id);
    const positions = vacancies
      .filter((vacancy) => !clean(vacancy.object_id) || clean(vacancy.object_id) === objectId)
      .map((vacancy) => ({
        id: clean(vacancy.id),
        title: clean(vacancy.title),
        salaryText: clean(vacancy.salary_text),
        scheduleText: clean(vacancy.schedule_text),
        conditionsText: clean(vacancy.conditions_text),
      }));
    return {
      id: objectId,
      title: clean(object.name),
      shortDescription: clean(object.comment) || clean(object.address) || `Строительный объект: ${clean(object.name)}`,
      conditions: positions
        .flatMap((item) => [item.salaryText, item.scheduleText, item.conditionsText])
        .filter((value, index, all) => value && all.indexOf(value) === index),
      positions,
    };
  }).filter((object) => object.id && object.title && object.positions.length > 0);

  return json({ companyId: COMPANY_ID, objects });
}

async function findExisting(externalApplicationId: string): Promise<JsonMap | null> {
  const { data, error } = await admin.from("recruitment_applications")
    .select("id,status,created_at")
    .eq("company_id", COMPANY_ID)
    .eq("source", SOURCE)
    .eq("external_application_id", externalApplicationId)
    .maybeSingle();
  if (error) throw error;
  return data as JsonMap | null;
}

async function submitApplication(input: ApplicationInput): Promise<Response> {
  const externalApplicationId = clean(input.externalApplicationId);
  const externalUserId = clean(input.maxUserId);
  const externalChatId = clean(input.maxChatId) || externalUserId;
  const fullName = clean(input.fullName);
  const phone = normalizePhone(input.phone);
  const citizenship = clean(input.citizenship);
  const objectId = clean(input.objectId);
  const vacancyId = clean(input.vacancyId);
  const age = Number.parseInt(clean(input.age), 10);

  if (!externalApplicationId || !externalUserId || !externalChatId) {
    return json({ error: "missing_external_identity" }, 400);
  }
  if (fullName.length < 5 || !phone || !citizenship || !objectId || !vacancyId) {
    return json({ error: "missing_required_fields" }, 400);
  }

  const existing = await findExisting(externalApplicationId);
  if (existing) {
    const id = clean(existing.id);
    return json({ applicationId: id, number: applicationNumber(id), created: false });
  }

  const [objectResult, vacancyResult] = await Promise.all([
    admin.from("objects")
      .select("id,name")
      .eq("company_id", COMPANY_ID)
      .eq("id", objectId)
      .eq("is_active", true)
      .maybeSingle(),
    admin.from("recruitment_vacancies")
      .select("id,object_id,title")
      .eq("company_id", COMPANY_ID)
      .eq("id", vacancyId)
      .eq("is_active", true)
      .maybeSingle(),
  ]);
  if (objectResult.error) throw objectResult.error;
  if (vacancyResult.error) throw vacancyResult.error;
  if (!objectResult.data) return json({ error: "object_not_found" }, 400);
  if (!vacancyResult.data) return json({ error: "vacancy_not_found" }, 400);
  if (clean(vacancyResult.data.object_id) && clean(vacancyResult.data.object_id) !== objectId) {
    return json({ error: "vacancy_object_mismatch" }, 400);
  }

  const now = new Date().toISOString();
  const readyText = clean(input.readyText);
  const comment = clean(input.comment);
  const hrComment = [
    comment && `Комментарий: ${comment}`,
    Number.isInteger(age) && age > 0 && `Возраст: ${age}`,
    readyText && `Готовность: ${readyText}`,
    clean(input.maxDisplayName) && `MAX: ${clean(input.maxDisplayName)}`,
  ].filter(Boolean).join("\n");

  const { data, error } = await admin.from("recruitment_applications").insert({
    company_id: COMPANY_ID,
    source: SOURCE,
    external_application_id: externalApplicationId,
    external_user_id: externalUserId,
    external_chat_id: externalChatId,
    external_username: clean(input.maxUsername),
    full_name: fullName,
    phone,
    citizenship,
    object_id: objectId,
    vacancy_id: vacancyId,
    position_title: clean(vacancyResult.data.title) || clean(input.positionTitle),
    experience_text: clean(input.experience),
    ready_date: parseReadyDate(readyText),
    status: "new",
    consent_personal_data: true,
    consented_at: now,
    submitted_at: now,
    updated_at: now,
    hr_comment: hrComment,
    custom_values: {
      age: Number.isInteger(age) ? age : null,
      ready_text: readyText,
      comment,
      max_display_name: clean(input.maxDisplayName),
      max_username: clean(input.maxUsername),
      integration: "max-recruitment-bot-v3",
    },
  }).select("id,status,stage_id").single();

  if (error) {
    const duplicate = await findExisting(externalApplicationId);
    if (duplicate) {
      const id = clean(duplicate.id);
      return json({ applicationId: id, number: applicationNumber(id), created: false });
    }
    throw error;
  }

  const applicationId = clean(data.id);
  await admin.from("recruitment_status_history").insert({
    company_id: COMPANY_ID,
    application_id: applicationId,
    status: "new",
    stage_id: clean(data.stage_id) || null,
    stage_title: "Новые",
    comment: "Кандидат отправил заявку через MAX",
    source: "max_bot",
  });
  await notifyRoles(
    "Новая заявка из MAX",
    `${fullName} · ${clean(vacancyResult.data.title)} · ${clean(objectResult.data.name)}`,
    applicationId,
    clean(objectResult.data.name),
  );
  return json({ applicationId, number: applicationNumber(applicationId), created: true }, 201);
}

async function resolveApplication(payload: RequestPayload): Promise<JsonMap | null> {
  let query = admin.from("recruitment_applications")
    .select("id,company_id,full_name,object_id,external_user_id,external_chat_id,source,archived_at,objects(name)")
    .eq("company_id", COMPANY_ID)
    .eq("source", SOURCE);

  const applicationId = clean(payload.applicationId);
  const externalApplicationId = clean(payload.externalApplicationId);
  if (applicationId) query = query.eq("id", applicationId);
  else if (externalApplicationId) query = query.eq("external_application_id", externalApplicationId);
  else if (clean(payload.maxChatId)) {
    query = query.eq("external_chat_id", clean(payload.maxChatId)).order("created_at", { ascending: false }).limit(1);
  } else if (clean(payload.maxUserId)) {
    query = query.eq("external_user_id", clean(payload.maxUserId)).order("created_at", { ascending: false }).limit(1);
  } else {
    return null;
  }

  const { data, error } = await query.maybeSingle();
  if (error) throw error;
  return data as JsonMap | null;
}

async function ingestMessage(payload: RequestPayload): Promise<Response> {
  const text = clean(payload.text);
  const maxMessageId = clean(payload.maxMessageId);
  if (!text || text.length > 3500) return json({ error: "invalid_message" }, 400);

  const application = await resolveApplication(payload);
  if (!application || application.archived_at) return json({ error: "application_not_found" }, 404);

  const { data, error } = await admin.from("recruitment_messages").insert({
    company_id: COMPANY_ID,
    application_id: clean(application.id),
    direction: "inbound",
    message_text: text,
    transport: "max",
    external_message_id: maxMessageId || null,
    delivery_status: "received",
  }).select("id").single();
  if (error) {
    if (String(error.code) === "23505") return json({ ok: true, duplicate: true });
    throw error;
  }

  const objectRow = relation(application.objects);
  await notifyRoles(
    "Новое сообщение кандидата в MAX",
    `${clean(application.full_name) || "Кандидат"} · ${text.slice(0, 140)}`,
    clean(application.id),
    clean(objectRow.name),
  );
  return json({ ok: true, messageId: clean(data.id) }, 201);
}

async function recoverStaleOutboundMessages(): Promise<void> {
  const stale = new Date(Date.now() - 2 * 60_000).toISOString();
  const { error } = await admin.from("recruitment_messages")
    .update({ delivery_status: "failed", delivery_error: "Истёк срок блокировки отправки" })
    .eq("transport", "max")
    .eq("direction", "outbound")
    .eq("delivery_status", "sending")
    .lt("last_delivery_attempt_at", stale);
  if (error) throw error;
}

async function pullOutbound(recoverStale: boolean): Promise<Response> {
  const now = new Date().toISOString();
  if (recoverStale) await recoverStaleOutboundMessages();

  const { data, error } = await admin.from("recruitment_messages")
    .select("id,application_id,message_text,delivery_attempts,available_at,recruitment_applications!inner(external_user_id,external_chat_id,source,archived_at)")
    .eq("transport", "max")
    .eq("direction", "outbound")
    .in("delivery_status", ["pending", "failed"])
    .lt("delivery_attempts", 10)
    .lte("available_at", now)
    .eq("recruitment_applications.source", "max")
    .is("recruitment_applications.archived_at", null)
    .order("available_at")
    .order("created_at")
    .limit(20);
  if (error) throw error;

  const claimed: JsonMap[] = [];
  for (const row of (data ?? []) as JsonMap[]) {
    const attempts = Number(row.delivery_attempts ?? 0) + 1;
    const { data: updated, error: updateError } = await admin.from("recruitment_messages")
      .update({
        delivery_status: "sending",
        delivery_attempts: attempts,
        last_delivery_attempt_at: now,
        delivery_error: "",
      })
      .eq("id", clean(row.id))
      .in("delivery_status", ["pending", "failed"])
      .lte("available_at", now)
      .select("id")
      .maybeSingle();
    if (updateError) throw updateError;
    if (!updated) continue;

    const application = relation(row.recruitment_applications);
    claimed.push({
      messageId: clean(row.id),
      applicationId: clean(row.application_id),
      maxUserId: clean(application.external_user_id),
      maxChatId: clean(application.external_chat_id),
      text: clean(row.message_text),
      attempt: attempts,
    });
  }
  return json({ messages: claimed });
}

async function acknowledgeOutbound(payload: RequestPayload): Promise<Response> {
  const messageId = clean(payload.messageId);
  if (!messageId) return json({ error: "missing_message_id" }, 400);
  const errorText = clean(payload.error);
  const sent = !errorText;

  const { error } = await admin.from("recruitment_messages").update({
    delivery_status: sent ? "sent" : "failed",
    external_message_id: sent ? clean(payload.maxMessageId) || null : null,
    sent_at: sent ? new Date().toISOString() : null,
    delivery_error: errorText.slice(0, 500),
  })
    .eq("id", messageId)
    .eq("transport", "max")
    .eq("direction", "outbound");
  if (error) throw error;
  return json({ ok: true });
}

Deno.serve(async (request: Request) => {
  try {
    if (!(await authorized(request))) return json({ error: "forbidden" }, 403);
    const url = new URL(request.url);

    if (request.method === "GET") {
      return url.searchParams.get("action") === "pull_outbound"
        ? await pullOutbound(url.searchParams.get("recover_stale") === "1")
        : await catalog();
    }
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

    const payload = await request.json() as RequestPayload;
    switch (clean(payload.action) || "submit_application") {
      case "submit_application":
        return await submitApplication(payload.application ?? {});
      case "ingest_message":
        return await ingestMessage(payload);
      case "ack_outbound":
        return await acknowledgeOutbound(payload);
      default:
        return json({ error: "unsupported_action" }, 400);
    }
  } catch (error) {
    console.error("MAX recruitment bridge failed", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
