import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.5";

import type { GlobalVoiceConversationContext } from "./conversation_context.ts";
import { buildCandidateReadinessGoal } from "./goal_candidate_readiness.ts";
import { buildOperationalRiskGoal } from "./goal_operational_risk.ts";
import type { BuilderResult, GoalKind } from "./goal_planner_shared.ts";
import { normalized } from "./shared.ts";

function contextGoalKind(context: GlobalVoiceConversationContext): GoalKind | null {
  if (context.topic === "goal_candidate_readiness") return "candidate_readiness";
  if (context.topic === "goal_operational_risk") return "operational_risk";
  return null;
}

function shortGoalFollowUp(prompt: string): boolean {
  const value = normalized(prompt);
  if (value.length > 140) return false;
  return /^(?:а\s+)?(?:только|лишь|покажи\s+только|оставь\s+только|что\s+с|подготовь|напомни|напиши|сделай\s+что\s+мож)/.test(value);
}

export function goalPlannerIntent(
  prompt: string,
  conversationContext: GlobalVoiceConversationContext,
): boolean {
  if (contextGoalKind(conversationContext) != null && shortGoalFollowUp(prompt)) {
    return true;
  }
  const value = normalized(prompt);
  const goalMarker = /(?:разберись|проверь\s+готовност|проверь.*что.*не\s+готов|кто.*не\s+готов|что\s+не\s+готово|что\s+мешает|покажи.*только.*проблем|только\s+проблем|что\s+горит|где\s+проблем|риски\s+по|слабые\s+места|оперативн.*сводк|готовност.*(?:вылет|заезд|объект|смен)|проверь.*(?:вылет|заезд).*(?:готов|проблем))/.test(value);
  if (!goalMarker) return false;
  const candidate = /(?:кандидат|вылет|заезд|рейс|прилет|билет|документ)/.test(value);
  const operational = /(?:объект|стройк|смен|табел|задач|снабжен|закуп|компани|что\s+горит)/.test(value);
  return candidate || operational;
}

function goalKind(
  prompt: string,
  conversationContext: GlobalVoiceConversationContext,
): GoalKind | null {
  const inherited = contextGoalKind(conversationContext);
  if (inherited != null && shortGoalFollowUp(prompt)) return inherited;
  const value = normalized(prompt);
  if (/(?:кандидат|вылет|заезд|рейс|прилет|билет|документ)/.test(value)) {
    return "candidate_readiness";
  }
  if (/(?:объект|стройк|смен|табел|задач|снабжен|закуп|компани|что\s+горит)/.test(value)) {
    return "operational_risk";
  }
  return null;
}

export async function buildGoalVoicePlan({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
  date,
  baseDate,
  conversationContext,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
  date: string;
  baseDate: string;
  conversationContext: GlobalVoiceConversationContext;
}): Promise<BuilderResult | null> {
  if (!goalPlannerIntent(prompt, conversationContext)) return null;
  const kind = goalKind(prompt, conversationContext);
  if (kind === "candidate_readiness") {
    return await buildCandidateReadinessGoal({
      client,
      companyId,
      role,
      assignedObject,
      requestedObject,
      prompt,
      date,
      conversationContext,
    });
  }
  if (kind === "operational_risk") {
    return await buildOperationalRiskGoal({
      client,
      companyId,
      role,
      assignedObject,
      requestedObject,
      prompt,
      date,
      baseDate,
      conversationContext,
    });
  }
  return null;
}
