import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";

Deno.serve(() => {
  return Response.json(
    { error: "diagnostic_function_removed" },
    {
      status: 410,
      headers: { "cache-control": "no-store" },
    },
  );
});
