import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import type { GlobalVoiceConversationContext } from "./conversation_context.ts";
import { buildGoalVoicePlan, goalPlannerIntent } from "./goal_planner.ts";
import {
  buildMultiStepVoicePlan as buildV15MultiStepVoicePlan,
  multiStepPlanIntent as v15MultiStepPlanIntent,
} from "./multi_step_plan_v15.ts";

type BuilderResult =
  | { body: Record<string, unknown>; status: number }
  | { error: string; status: number };

const emptyConversationContext: GlobalVoiceConversationContext = {
  topic: "",
  queryMode: "",
  date: "",
  prompt: "",
  objectName: "",
};

function currentDateKey(): string {
  return new Date().toISOString().slice(0, 10);
}

/// v16 is an additive layer over the frozen v15 deterministic planner.
/// Goal-oriented requests are diagnosed across several live domains first.
/// Every other phrase is delegated to the exact v15 implementation copied to
/// multi_step_plan_v15.ts, so the established direct command surface remains
/// unchanged.
export function multiStepPlanIntent(
  prompt: string,
  conversationContext: GlobalVoiceConversationContext = emptyConversationContext,
): boolean {
  return goalPlannerIntent(prompt, conversationContext) ||
    v15MultiStepPlanIntent(prompt);
}

export async function buildMultiStepVoicePlan({
  client,
  companyId,
  role,
  assignedObject,
  requestedObject,
  prompt,
  date,
  baseDate,
  conversationContext = emptyConversationContext,
}: {
  client: SupabaseClient;
  companyId: string;
  role: string;
  assignedObject: string;
  requestedObject: string;
  prompt: string;
  date: string;
  baseDate?: string;
  conversationContext?: GlobalVoiceConversationContext;
}): Promise<BuilderResult | null> {
  const goal = await buildGoalVoicePlan({
    client,
    companyId,
    role,
    assignedObject,
    requestedObject,
    prompt,
    date,
    baseDate: baseDate || currentDateKey(),
    conversationContext,
  });
  if (goal != null) return goal;

  return await buildV15MultiStepVoicePlan({
    client,
    companyId,
    role,
    assignedObject,
    requestedObject,
    prompt,
    date,
  });
}
