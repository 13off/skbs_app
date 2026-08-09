import { clean, normalized } from "./shared.ts";

export type GlobalVoiceConversationContext = {
  topic: string;
  queryMode: string;
  date: string;
  prompt: string;
  objectName: string;
};

const supportedTopics = new Set(["employees", "tasks", "candidates", "procurement"]);
const supportedModes = new Set(["count", "list"]);

export function parseGlobalVoiceConversationContext(
  value: unknown,
): GlobalVoiceConversationContext {
  const raw = value && typeof value === "object"
    ? value as Record<string, unknown>
    : {};
  const topicRaw = clean(raw.topic, 40);
  const modeRaw = clean(raw.query_mode, 20);
  const dateRaw = clean(raw.date, 10);
  return {
    topic: supportedTopics.has(topicRaw) ? topicRaw : "",
    queryMode: supportedModes.has(modeRaw) ? modeRaw : "",
    date: /^20\d{2}-\d{2}-\d{2}$/.test(dateRaw) ? dateRaw : "",
    prompt: clean(raw.prompt, 800),
    objectName: clean(raw.object_name, 180),
  };
}

function explicitTopic(value: string): boolean {
  return /(?:сотрудник|работник|люд|человек|бригада|задач|наряд|кандидат|соискател|заявк|закуп|снабжен)/.test(
    value,
  );
}

function shortFollowUp(value: string): boolean {
  if (value.length > 90) return false;
  return /^(?:а\s+)?(?:сколько(?:\s+их)?|их\s+сколько|кто(?:\s+именно)?|какие(?:\s+именно)?|перечисли(?:\s+их)?|покажи\s+их|а\s+они|а\s+их|на\s+(?:сегодня|завтра|послезавтра)|а\s+(?:сегодня|завтра|послезавтра)|а\s+на\s+(?:сегодня|завтра|послезавтра)|что\s+по\s+ним)[?!.\s]*$/.test(
    value,
  );
}

function requestedMode(value: string, fallback: string): string {
  if (/(?:кто|какие|перечисли|покажи\s+их|что\s+по\s+ним)/.test(value)) {
    return "list";
  }
  if (/(?:сколько|их\s+сколько)/.test(value)) return "count";
  return supportedModes.has(fallback) ? fallback : "count";
}

function relativeDate(value: string): string {
  if (/послезавтра/.test(value)) return "послезавтра";
  if (/завтра/.test(value)) return "завтра";
  if (/сегодня/.test(value)) return "сегодня";
  return "";
}

function topicPrompt(topic: string, mode: string): string {
  switch (topic) {
    case "employees":
      return mode === "list" ? "кто сотрудники" : "сколько сотрудников";
    case "tasks":
      return mode === "list" ? "какие задачи" : "сколько задач";
    case "candidates":
      return mode === "list" ? "кто кандидаты" : "сколько кандидатов";
    case "procurement":
      return mode === "list" ? "какие заявки снабжения" : "сколько заявок снабжения";
    default:
      return "";
  }
}

export function resolveGlobalVoiceConversationPrompt({
  prompt,
  context,
}: {
  prompt: string;
  context: GlobalVoiceConversationContext;
}): { prompt: string; inherited: boolean } {
  const raw = clean(prompt, 4000);
  const value = normalized(raw);
  if (!raw || !context.topic || explicitTopic(value) || !shortFollowUp(value)) {
    return { prompt: raw, inherited: false };
  }

  const mode = requestedMode(value, context.queryMode);
  let resolved = topicPrompt(context.topic, mode);
  if (!resolved) return { prompt: raw, inherited: false };

  if (context.topic === "tasks") {
    finalDate: {
      const relative = relativeDate(value);
      if (relative) {
        resolved += ` ${relative}`;
        break finalDate;
      }
      if (context.date) resolved += ` ${context.date}`;
    }
  }

  return { prompt: resolved, inherited: true };
}
