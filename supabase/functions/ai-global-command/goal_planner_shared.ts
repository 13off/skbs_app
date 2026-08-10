import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import { clean, nameMatches, normalized, resultWithAction } from "./shared.ts";

export type BuilderResult =
  | { body: Record<string, unknown>; status: number }
  | { error: string; status: number };

export type GoalKind = "candidate_readiness" | "operational_risk";
export type GoalObject = { id: string; name: string };

export const maxGoalWrites = 12;

export function managerRole(role: string) {
  return role === "admin" || role === "owner" || role === "developer";
}

export function hrRole(role: string) {
  return managerRole(role) || role === "hr";
}

export function operationalRole(role: string) {
  return managerRole(role) || role === "foreman";
}

export function dateIsOnOrBefore(left: string, right: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(left) &&
    /^\d{4}-\d{2}-\d{2}$/.test(right) &&
    left <= right;
}

async function loadObjects(
  client: SupabaseClient,
  companyId: string,
): Promise<GoalObject[]> {
  const { data, error } = await client
    .from("objects")
    .select("id, name")
    .eq("company_id", companyId)
    .eq("is_active", true)
    .order("name")
    .limit(300);
  if (error) throw error;
  return (data ?? []) as GoalObject[];
}

export async function resolveGoalObjectScope({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
}): Promise<GoalObject | { error: string; status: number } | null> {
  const objects = await loadObjects(client, companyId);
  if (role === "foreman") {
    const expected = normalized(assignedObject);
    const exact = objects.filter((item) => normalized(item.name) === expected);
    return exact.length === 1
      ? exact[0]
      : { error: "Не удалось подтвердить объект прораба", status: 403 };
  }

  const explicit = clean(requestedObject, 180);
  if (explicit) {
    const exact = objects.filter((item) => normalized(item.name) === normalized(explicit));
    if (exact.length === 1) return exact[0];
  }

  const mentioned = objects.filter((item) => nameMatches(prompt, item.name));
  if (mentioned.length === 1) return mentioned[0];
  if (mentioned.length > 1) {
    return {
      error: `Нашёл несколько объектов: ${mentioned.slice(0, 5).map((item) => item.name).join(", ")}. Уточни объект.`,
      status: 409,
    };
  }
  return null;
}

function goalMetadata({
  kind,
  checks,
  issueCount,
  affectedCount,
}: {
  kind: GoalKind;
  checks: string[];
  issueCount: number;
  affectedCount: number;
}) {
  return {
    version: 16,
    source: "deterministic_goal_planner",
    kind,
    checks,
    issue_count: issueCount,
    affected_count: affectedCount,
  };
}

export function readOnlyGoalBody({
  kind,
  title,
  summary,
  highlights,
  warnings,
  nextSteps,
  date,
  objectName,
  prompt,
  conversationTopic,
  conversationMode,
  checks,
  issueCount,
  affectedCount,
}: {
  kind: GoalKind;
  title: string;
  summary: string;
  highlights: string[];
  warnings: string[];
  nextSteps: string[];
  date: string;
  objectName: string;
  prompt: string;
  conversationTopic: string;
  conversationMode: string;
  checks: string[];
  issueCount: number;
  affectedCount: number;
}) {
  return {
    ok: true,
    mode: "global_voice",
    title,
    summary,
    highlights: highlights.slice(0, 18),
    warnings,
    next_steps: nextSteps,
    scope: {
      object_name: objectName || "Все доступные объекты",
      date,
    },
    preliminary: true,
    ai_used: false,
    goal: goalMetadata({ kind, checks, issueCount, affectedCount }),
    conversation: {
      topic: conversationTopic,
      query_mode: conversationMode,
      date,
      prompt: clean(prompt, 1500),
      object_name: objectName,
    },
  };
}

export function actionGoalBody({
  kind,
  title,
  summary,
  highlights,
  warnings,
  nextSteps,
  date,
  objectName,
  checks,
  issueCount,
  affectedCount,
  actions,
}: {
  kind: GoalKind;
  title: string;
  summary: string;
  highlights: string[];
  warnings: string[];
  nextSteps: string[];
  date: string;
  objectName: string;
  checks: string[];
  issueCount: number;
  affectedCount: number;
  actions: Record<string, unknown>[];
}) {
  const action = actions.length === 1
    ? actions[0]
    : {
      id: crypto.randomUUID(),
      type: "voice_compound_batch",
      title: `Выполнить ${actions.length} безопасно подготовленных действий`,
      button_label: `Проверить ${actions.length} действий`,
      confirmation_required: true,
      payload: {
        actions,
        planner_version: 16,
        planner_kind: kind,
      },
    };
  const base = resultWithAction({
    title,
    summary,
    highlights: highlights.slice(0, 18),
    warnings,
    objectName,
    date,
    action,
  });
  return {
    ...base,
    next_steps: nextSteps,
    goal: goalMetadata({ kind, checks, issueCount, affectedCount }),
  };
}
