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
    const timeoutMs = Math.max(
      1000,
      Math.min(30000, Number(options.timeout ?? 8) * 1000),
    );
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ model, input: openAIInput }),
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

// Supabase.ai уже существует в Edge Runtime. Меняем только Session на адаптер
// OpenAI. Сам global Supabase не переназначаем: его свойство в runtime не имеет
// обычного writable setter и повторное присваивание завершает worker с 500.
const runtime = (globalThis as unknown as { Supabase?: any }).Supabase;
if (runtime?.ai) {
  runtime.ai.Session = OpenAISession;
}

// Deno.env.set() в managed Edge Runtime не поддерживается. Semantic router
// читает три служебные переменные через Deno.env.get(), поэтому подмешиваем их
// только на чтении, не затрагивая реальные Secrets проекта.
const originalEnvGet = Deno.env.get.bind(Deno.env);
(Deno.env as unknown as { get: (name: string) => string | undefined }).get = (
  name: string,
) => {
  if (name === "AI_INFERENCE_API_HOST") return "openai";
  if (name === "AI_SEMANTIC_MODE") return "openaicompatible";
  if (name === "AI_SEMANTIC_MODEL") {
    return originalEnvGet("OPENAI_MODEL")?.trim() || "gpt-5-mini";
  }
  return originalEnvGet(name);
};

await import(
  "https://raw.githubusercontent.com/13off/skbs_app/1fe532492041f1bcd66035193a665a95d3668b5f/supabase/functions/ai-global-command/index.ts"
);
