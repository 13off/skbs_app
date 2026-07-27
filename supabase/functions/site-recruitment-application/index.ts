import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

const COMPANY_ID = "e39c8fd5-e7f3-4beb-a269-76e893975a98";
const MURMANSK_OBJECT_ID = "7ff4ebbf-ade6-42da-b101-1ba196565833";
const MURMANSK_OBJECT_NAME = "Мурманск";
const SOURCE = "site";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ALLOWED_ORIGINS = new Set([
  "https://appstroy-web-c0ef3.ilyaodincev1999.workers.dev",
]);
const VACANCIES = {
  concrete: {
    id: "683451ca-b241-407f-b338-fafe94596355",
    title: "Бетонщик-арматурщик",
    objectId: MURMANSK_OBJECT_ID,
    objectName: MURMANSK_OBJECT_NAME,
  },
  general: {
    id: "4b8ef5ee-593b-4e50-aed6-257f065e6040",
    title: "Разнорабочий",
    objectId: MURMANSK_OBJECT_ID,
    objectName: MURMANSK_OBJECT_NAME,
  },
  foreman: {
    id: "1c7d7aa1-0044-40fb-97d9-a83ee7ca1d2d",
    title: "Мастер-прораб",
    objectId: MURMANSK_OBJECT_ID,
    objectName: MURMANSK_OBJECT_NAME,
  },
  site_manager: {
    id: "1c9f54ad-47e4-417f-92d1-9f458e62aaf1",
    title: "Начальник участка",
    objectId: MURMANSK_OBJECT_ID,
    objectName: MURMANSK_OBJECT_NAME,
  },
} as const;

type JsonMap = Record<string, unknown>;
type VacancyKey = keyof typeof VACANCIES;
type SiteApplicationPayload = {
  requestId?: string;
  vacancyKey?: string;
  fullName?: string;
  phone?: string;
  city?: string;
  experience?: string;
  comment?: string;
  consent?: boolean;
  website?: string;
  startedAt?: number;
  sourceUrl?: string;
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

function normalizePhone(value: unknown): string {
  let digits = clean(value).replace(/\D/g, "");
  if (digits.length === 11 && digits.startsWith("8")) digits = `7${digits.slice(1)}`;
  if (digits.length === 10) digits = `7${digits}`;
  if (digits.length < 10 || digits.length > 15) return "";
  return `+${digits}`;
}

function applicationNumber(id: string): string {
  return id.replaceAll("-", "").slice(-8).toUpperCase();
}

function corsHeaders(origin: string): HeadersInit {
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "content-type",
    "access-control-max-age": "86400",
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "vary": "Origin",
  };
}

function json(origin: string, body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders(origin) });
}

function originFor(request: Request): string {
  const origin = clean(request.headers.get("origin"));
  return ALLOWED_ORIGINS.has(origin) ? origin : "";
}

function resolveVacancy(value: unknown) {
  const key = clean(value) as VacancyKey;
  return VACANCIES[key] ? { key, ...VACANCIES[key] } : null;
}

async function notifyRoles(
  applicationId: string,
  fullName: string,
  vacancy: NonNullable<ReturnType<typeof resolveVacancy>>,
): Promise<void> {
  const rows = ["admin", "hr"].map((role) => ({
    company_id: COMPANY_ID,
    title: "Новая заявка с сайта",
    body: `${fullName} · ${vacancy.title} · ${vacancy.objectName}`,
    actor_name: "Кандидат",
    actor_email: "",
    object_name: vacancy.objectName,
    entity_type: "recruitment_application",
    entity_id: applicationId,
    target_role: role,
    requires_action: true,
    priority: "high",
    source_role: "system",
    push_requested: true,
  }));
  const { error } = await admin.from("app_notifications").insert(rows);
  if (error) console.error("Site recruitment notification failed", error);
}

async function findRecentByPhone(phone: string, vacancyId: string): Promise<JsonMap | null> {
  const since = new Date(Date.now() - 30 * 60_000).toISOString();
  const { data, error } = await admin
    .from("recruitment_applications")
    .select("id,created_at")
    .eq("company_id", COMPANY_ID)
    .eq("source", SOURCE)
    .eq("phone", phone)
    .eq("vacancy_id", vacancyId)
    .gte("created_at", since)
    .is("archived_at", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data as JsonMap | null;
}

Deno.serve(async (request: Request) => {
  const origin = originFor(request);

  if (request.method === "OPTIONS") {
    if (!origin) return new Response(null, { status: 403 });
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (!origin) return Response.json({ error: "forbidden_origin" }, { status: 403 });
  if (request.method !== "POST") return json(origin, { error: "method_not_allowed" }, 405);

  try {
    const contentType = clean(request.headers.get("content-type")).toLowerCase();
    if (!contentType.startsWith("application/json")) {
      return json(origin, { error: "invalid_content_type" }, 415);
    }

    const raw = await request.text();
    if (!raw || raw.length > 12_000) return json(origin, { error: "invalid_payload" }, 400);
    const payload = JSON.parse(raw) as SiteApplicationPayload;

    if (clean(payload.website)) return json(origin, { ok: true, accepted: true }, 201);

    const startedAt = Number(payload.startedAt ?? 0);
    const elapsed = Date.now() - startedAt;
    if (!Number.isFinite(startedAt) || startedAt <= 0 || elapsed < 1200 || elapsed > 24 * 60 * 60_000) {
      return json(origin, { error: "invalid_form_timing" }, 400);
    }

    const vacancy = resolveVacancy(payload.vacancyKey);
    const fullName = clean(payload.fullName).replace(/\s+/g, " ");
    const phone = normalizePhone(payload.phone);
    const city = clean(payload.city).replace(/\s+/g, " ");
    const experience = clean(payload.experience);
    const comment = clean(payload.comment);
    const sourceUrl = clean(payload.sourceUrl).slice(0, 500);

    if (!vacancy) return json(origin, { error: "invalid_vacancy" }, 400);
    if (payload.consent !== true) return json(origin, { error: "consent_required" }, 400);
    if (fullName.length < 5 || fullName.length > 160) return json(origin, { error: "invalid_full_name" }, 400);
    if (!phone) return json(origin, { error: "invalid_phone" }, 400);
    if (city.length < 2 || city.length > 160) return json(origin, { error: "invalid_city" }, 400);
    if (experience.length > 500 || comment.length > 2000) return json(origin, { error: "text_too_long" }, 400);

    const recent = await findRecentByPhone(phone, vacancy.id);
    if (recent) {
      const id = clean(recent.id);
      return json(origin, {
        ok: true,
        created: false,
        applicationId: id,
        number: applicationNumber(id),
      });
    }

    const now = new Date().toISOString();
    const externalApplicationId = clean(payload.requestId) || crypto.randomUUID();
    const externalIdentity = `site:${externalApplicationId}`;
    const hrComment = [
      city && `Город: ${city}`,
      experience && `Опыт: ${experience}`,
      comment && `Комментарий: ${comment}`,
      sourceUrl && `Страница: ${sourceUrl}`,
    ].filter(Boolean).join("\n");

    const { data, error } = await admin
      .from("recruitment_applications")
      .insert({
        company_id: COMPANY_ID,
        source: SOURCE,
        external_application_id: externalApplicationId,
        external_user_id: externalIdentity,
        external_chat_id: externalIdentity,
        external_username: "",
        full_name: fullName,
        phone,
        citizenship: "Не указано",
        object_id: vacancy.objectId,
        vacancy_id: vacancy.id,
        position_title: vacancy.title,
        experience_text: experience,
        ready_date: null,
        status: "new",
        consent_personal_data: true,
        consented_at: now,
        submitted_at: now,
        updated_at: now,
        hr_comment: hrComment,
        custom_values: {
          city,
          experience,
          comment,
          vacancy_key: vacancy.key,
          source_url: sourceUrl,
          user_agent: clean(request.headers.get("user-agent")).slice(0, 500),
          integration: "skbs-recruitment-site-v3",
        },
      })
      .select("id,status,stage_id")
      .single();

    if (error) throw error;

    const applicationId = clean(data.id);
    await admin.from("recruitment_status_history").insert({
      company_id: COMPANY_ID,
      application_id: applicationId,
      status: "new",
      stage_id: clean(data.stage_id) || null,
      stage_title: "Новые",
      comment: `Кандидат отправил заявку через сайт СКБС: ${vacancy.title}`,
      source: "site",
    });
    await notifyRoles(applicationId, fullName, vacancy);

    return json(origin, {
      ok: true,
      created: true,
      applicationId,
      number: applicationNumber(applicationId),
    }, 201);
  } catch (error) {
    console.error("Site recruitment application failed", error);
    return json(origin, { error: "server_error" }, 500);
  }
});