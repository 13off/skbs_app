import "jsr:@supabase/functions-js/edge-runtime.d.ts";

function outputText(payload: any): string {
  if (typeof payload?.output_text === "string") return payload.output_text;
  const output = Array.isArray(payload?.output) ? payload.output : [];
  for (const item of output) {
    if (item?.type !== "message" || !Array.isArray(item?.content)) continue;
    for (const part of item.content) {
      if (part?.type === "output_text" && typeof part?.text === "string") {
        return part.text;
      }
    }
  }
  return "";
}

class OpenAISession {
  constructor(_requestedModel?: string) {}

  async run(
    input: { messages?: Array<{ role?: string; content?: unknown }> },
    options: { timeout?: number } = {},
  ) {
    const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "";
    if (!apiKey) throw new Error("OPENAI_API_KEY is not configured");

    const model = Deno.env.get("OPENAI_MODEL")?.trim() || "gpt-5-mini";
    const messages = Array.isArray(input?.messages) ? input.messages : [];
    const openAIInput = messages.map((message) => ({
      role: message.role === "system" ? "developer" : (message.role || "user"),
      content: String(message.content ?? ""),
    }));

    const controller = new AbortController();
    const timeoutMs = Math.max(1000, Math.min(30000, Number(options.timeout ?? 8) * 1000));
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          input: openAIInput,
        }),
        signal: controller.signal,
      });

      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(
          payload?.error?.message || `OpenAI API error ${response.status}`,
        );
      }

      return { response: outputText(payload) };
    } finally {
      clearTimeout(timer);
    }
  }
}

const runtime = (globalThis as unknown as { Supabase?: any }).Supabase ?? {};
runtime.ai = { ...(runtime.ai ?? {}), Session: OpenAISession };
(globalThis as unknown as { Supabase?: any }).Supabase = runtime;

try {
  Deno.env.set("AI_INFERENCE_API_HOST", "openai");
  Deno.env.set("AI_SEMANTIC_MODE", "openaicompatible");
  Deno.env.set(
    "AI_SEMANTIC_MODEL",
    Deno.env.get("OPENAI_MODEL")?.trim() || "gpt-5-mini",
  );
} catch (error) {
  console.warn("Unable to seed semantic-router compatibility env", error);
}

await import(
  "https://raw.githubusercontent.com/13off/skbs_app/1fe532492041f1bcd66035193a665a95d3668b5f/supabase/functions/ai-global-command/index.ts"
);
