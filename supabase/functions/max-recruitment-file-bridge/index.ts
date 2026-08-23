import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";

function json(body: unknown, status = 503): Response {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json; charset=utf-8",
      "retry-after": "3600",
    },
  });
}

// File intake follows the same temporary MAX pause as the recruiting bridge.
// Existing recruitment documents remain untouched in Supabase Storage.
Deno.serve(() =>
  json({
    error: "max_recruitment_temporarily_disabled",
    message: "MAX recruitment is temporarily disabled",
  })
);
