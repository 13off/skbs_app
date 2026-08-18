import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.5";

// Assistant-only operational endpoint. The plaintext secret is never stored in
// the repository or database; only its SHA-256 digest is committed here.
const EXPECTED_SECRET_SHA256 = "64c0f403520087e6d175b2da521cfd375656c5769c1a439de91e36f53d568321";
const BUCKET = "recruitment-documents";
const MAX_BYTES = 20 * 1024 * 1024;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function serviceKey() {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    try {
      const parsed = JSON.parse(modern);
      return parsed.default ?? Object.values(parsed)[0] ?? "";
    } catch (_) {}
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function safeName(value: string) {
  return value
      .trim()
      .replace(/[\\/:*?"<>|]/g, "_")
      .replace(/\s+/g, " ")
      .replace(/^\.+|\.+$/g, "")
      .slice(0, 180) || "ticket.pdf";
}

function decodeBase64(raw: string) {
  const value = raw.includes(",") ? raw.slice(raw.indexOf(",") + 1) : raw;
  const bin = atob(value.replace(/\s+/g, ""));
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

async function uploadPdf(
  admin: any,
  app: any,
  fileNameRaw: string,
  contentTypeRaw: string,
  raw: string,
) {
  const fileName = safeName(fileNameRaw);
  const contentType = String(contentTypeRaw || "application/pdf").toLowerCase();
  if (contentType !== "application/pdf") throw new Error("Only PDF supported");

  let bytes: Uint8Array;
  try {
    bytes = decodeBase64(raw);
  } catch (_) {
    throw new Error("Invalid base64");
  }

  if (!bytes.length || bytes.length > MAX_BYTES) {
    throw new Error("Invalid file size");
  }
  if (!(bytes[0] === 0x25 && bytes[1] === 0x50 && bytes[2] === 0x44 && bytes[3] === 0x46)) {
    throw new Error("File is not a PDF");
  }

  const storageName = fileName.replace(/\s+/g, "_");
  const path = `${app.company_id}/${app.id}/tickets/${Date.now()}_assistant_${crypto.randomUUID().slice(0, 8)}_${storageName}`;
  const { error } = await admin.storage.from(BUCKET).upload(path, bytes, {
    contentType,
    cacheControl: "3600",
    upsert: false,
  });
  if (error) throw error;

  return {
    bucket: BUCKET,
    path,
    original_name: fileName,
    mime_type: contentType,
    size_bytes: bytes.length,
  };
}

async function cleanup(admin: any, path?: string) {
  if (!path) return;
  try {
    await admin.storage.from(BUCKET).remove([path]);
  } catch (_) {}
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const secret = req.headers.get("x-assistant-secret") ?? "";
    if (!secret || (await sha256(secret)) !== EXPECTED_SECRET_SHA256) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json();
    const action = String(body.action ?? "upload");
    const applicationId = String(body.application_id ?? "").trim();
    if (!applicationId) return json({ error: "application_id required" }, 400);

    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const key = serviceKey();
    if (!url || !key) throw new Error("Supabase service configuration is missing");

    const admin = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: app, error: appError } = await admin
      .from("recruitment_applications")
      .select("id,company_id,full_name,stage_id,object_id")
      .eq("id", applicationId)
      .maybeSingle();
    if (appError) throw appError;
    if (!app) return json({ error: "Application not found" }, 404);

    if (action === "upload") {
      const raw = String(body.file_base64 ?? "");
      if (!raw) return json({ error: "file_base64 required" }, 400);
      const uploaded = await uploadPdf(
        admin,
        app,
        String(body.file_name ?? "ticket.pdf"),
        String(body.content_type ?? "application/pdf"),
        raw,
      );
      return json({ ok: true, ...uploaded, company_id: app.company_id, application_id: app.id }, 201);
    }

    if (action === "create_flight") {
      for (const key of ["departure_at", "origin", "destination", "file_base64"]) {
        if (!String(body[key] ?? "").trim()) return json({ error: `${key} required` }, 400);
      }

      const departureAt = String(body.departure_at);
      const { data: existing, error: existingError } = await admin
        .from("recruitment_flights")
        .select("id,ticket_path,ticket_original_name")
        .eq("company_id", app.company_id)
        .eq("application_id", app.id)
        .eq("departure_at", departureAt)
        .maybeSingle();
      if (existingError) throw existingError;
      if (existing) {
        return json({
          ok: true,
          reused: true,
          flight_id: existing.id,
          ticket_path: existing.ticket_path,
          ticket_original_name: existing.ticket_original_name,
        });
      }

      const uploaded = await uploadPdf(
        admin,
        app,
        String(body.file_name ?? "ticket.pdf"),
        String(body.content_type ?? "application/pdf"),
        String(body.file_base64 ?? ""),
      );

      try {
        const row = {
          company_id: app.company_id,
          application_id: app.id,
          object_id: body.object_id ? String(body.object_id) : app.object_id,
          departure_at: departureAt,
          arrival_at: body.arrival_at ? String(body.arrival_at) : null,
          origin: String(body.origin),
          destination: String(body.destination),
          flight_number: String(body.flight_number ?? ""),
          status: String(body.status ?? "scheduled"),
          remind_day_before: body.remind_day_before !== false,
          remind_three_hours: body.remind_three_hours !== false,
          ticket_bucket: uploaded.bucket,
          ticket_path: uploaded.path,
          ticket_original_name: uploaded.original_name,
          ticket_mime_type: uploaded.mime_type,
          ticket_size_bytes: uploaded.size_bytes,
          notes: String(body.notes ?? ""),
        };

        const { data: flight, error: flightError } = await admin
          .from("recruitment_flights")
          .insert(row)
          .select("id")
          .single();
        if (flightError) throw flightError;

        const { error: ticketError } = await admin
          .from("recruitment_flight_tickets")
          .insert({
            company_id: app.company_id,
            flight_id: flight.id,
            bucket: uploaded.bucket,
            path: uploaded.path,
            original_name: uploaded.original_name,
            mime_type: uploaded.mime_type,
            size_bytes: uploaded.size_bytes,
          });
        if (ticketError) {
          await admin.from("recruitment_flights").delete().eq("id", flight.id);
          throw ticketError;
        }

        const patch: Record<string, unknown> = {};
        if (body.object_id) patch.object_id = String(body.object_id);
        if (body.stage_id) patch.stage_id = String(body.stage_id);
        if (Object.keys(patch).length) {
          const { error: patchError } = await admin
            .from("recruitment_applications")
            .update(patch)
            .eq("id", app.id);
          if (patchError) throw patchError;
        }

        return json({ ok: true, created: true, flight_id: flight.id, ...uploaded }, 201);
      } catch (err) {
        await cleanup(admin, uploaded.path);
        throw err;
      }
    }

    if (action === "attach_ticket") {
      const flightId = String(body.flight_id ?? "").trim();
      const raw = String(body.file_base64 ?? "");
      if (!flightId || !raw) {
        return json({ error: "flight_id and file_base64 required" }, 400);
      }

      const { data: flight, error: flightError } = await admin
        .from("recruitment_flights")
        .select("id,company_id,application_id")
        .eq("id", flightId)
        .eq("company_id", app.company_id)
        .eq("application_id", app.id)
        .maybeSingle();
      if (flightError) throw flightError;
      if (!flight) return json({ error: "Flight not found for application" }, 404);

      const originalName = safeName(String(body.file_name ?? "ticket.pdf"));
      const { data: existingTicket, error: lookupError } = await admin
        .from("recruitment_flight_tickets")
        .select("id,path,original_name")
        .eq("company_id", app.company_id)
        .eq("flight_id", flight.id)
        .eq("original_name", originalName)
        .maybeSingle();
      if (lookupError) throw lookupError;
      if (existingTicket) {
        return json({
          ok: true,
          reused: true,
          ticket_id: existingTicket.id,
          path: existingTicket.path,
          original_name: existingTicket.original_name,
        });
      }

      const uploaded = await uploadPdf(
        admin,
        app,
        originalName,
        String(body.content_type ?? "application/pdf"),
        raw,
      );
      try {
        const { data: ticket, error: insertError } = await admin
          .from("recruitment_flight_tickets")
          .insert({
            company_id: app.company_id,
            flight_id: flight.id,
            bucket: uploaded.bucket,
            path: uploaded.path,
            original_name: uploaded.original_name,
            mime_type: uploaded.mime_type,
            size_bytes: uploaded.size_bytes,
          })
          .select("id")
          .single();
        if (insertError) throw insertError;
        return json({ ok: true, created: true, ticket_id: ticket.id, flight_id: flight.id, ...uploaded }, 201);
      } catch (err) {
        await cleanup(admin, uploaded.path);
        throw err;
      }
    }

    return json({ error: "Unsupported action" }, 400);
  } catch (err) {
    console.error(err);
    return json({ error: err instanceof Error ? err.message : String(err) }, 500);
  }
});
