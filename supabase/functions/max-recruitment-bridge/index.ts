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

// MAX recruiting is intentionally paused. Keep the function deployed so the
// integration can be restored by reverting this commit without changing URLs,
// secrets, tables or the candidate data already stored in AppСтрой.
Deno.serve(() =>
  json({
    error: "max_recruitment_temporarily_disabled",
    message: "MAX recruitment is temporarily disabled",
  })
);
