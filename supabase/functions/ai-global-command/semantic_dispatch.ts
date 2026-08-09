import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import { buildBulkTimesheetResult } from "./bulk_timesheet.ts";
import {
  buildCandidateResponsible,
  buildCreateLegalMatter,
  buildCreateProcurementRequest,
} from "./extended_actions.ts";
import { buildNavigationResult, navigationTarget } from "./navigation.ts";
import { buildOperationalQuery } from "./operational_queries.ts";
import {
  buildHrStageMove,
  buildLegalDecision,
  buildProcurementStatus,
} from "./professional_actions.ts";
import {
  type SemanticRoute,
  semanticPrompt,
} from "./semantic_router.ts";

type DispatchResult =
  | { body: Record<string, unknown>; status: number }
  | { error: string; status: number };

function clean(value: unknown, max = 1000): string {
  return String(value ?? "").trim().slice(0, max);
}

function isBuilderError(value: unknown): value is { error: string; status: number } {
  if (!value || typeof value !== "object") return false;
  return "error" in (value as Record<string, unknown>);
}

async function invokeAssistantFunction({
  functionName,
  supabaseUrl,
  publishable,
  authorization,
  companyId,
  objectName,
  date,
  prompt,
}: {
  functionName: string;
  supabaseUrl: string;
  publishable: string;
  authorization: string;
  companyId: string;
  objectName: string;
  date: string;
  prompt: string;
}): Promise<DispatchResult> {
  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/${functionName}`, {
      method: "POST",
      headers: {
        Authorization: authorization,
        apikey: publishable,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        mode: "chat",
        company_id: companyId,
        object_name: objectName || null,
        date,
        prompt,
      }),
    });
    const data = await response.json().catch(() => ({})) as Record<string, unknown>;
    const error = clean(data.error);
    if (!response.ok || error) {
      return {
        error: error || "Семантический помощник временно недоступен",
        status: response.status || 500,
      };
    }
    return { body: data, status: response.status };
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : String(error),
      status: 500,
    };
  }
}

export async function dispatchSemanticVoice({
  route,
  client,
  companyId,
  role,
  userId,
  assignedObject,
  requestedObject,
  date,
  originalPrompt,
  supabaseUrl,
  publishable,
  authorization,
}: {
  route: SemanticRoute;
  client: SupabaseClient;
  companyId: string;
  role: string;
  userId: string;
  assignedObject: string;
  requestedObject: string;
  date: string;
  originalPrompt: string;
  supabaseUrl: string;
  publishable: string;
  authorization: string;
}): Promise<DispatchResult | null> {
  const prompt = semanticPrompt(route, originalPrompt);

  switch (route.intent) {
    case "query_employees":
    case "query_tasks":
    case "query_candidates":
    case "query_procurement": {
      return await buildOperationalQuery({
        client,
        companyId,
        role,
        assignedObject,
        requestedObject,
        prompt,
        date,
      });
    }
    case "hr_stage_move": {
      return await buildHrStageMove({ client, companyId, role, prompt, date });
    }
    case "candidate_responsible": {
      return await buildCandidateResponsible({
        client,
        companyId,
        role,
        prompt,
        date,
      });
    }
    case "procurement_create": {
      return await buildCreateProcurementRequest({
        client,
        companyId,
        role,
        assignedObject,
        requestedObject,
        prompt,
        date,
      });
    }
    case "procurement_status": {
      return await buildProcurementStatus({
        client,
        companyId,
        role,
        prompt,
        date,
        requestedObject,
      });
    }
    case "legal_create": {
      return await buildCreateLegalMatter({
        client,
        companyId,
        role,
        requestedObject,
        prompt,
        date,
      });
    }
    case "legal_decision": {
      return await buildLegalDecision({ client, companyId, role, prompt, date });
    }
    case "timesheet_bulk": {
      return await buildBulkTimesheetResult({
        client,
        companyId,
        role,
        assignedObject,
        requestedObject,
        prompt,
        date,
      });
    }
    case "navigation": {
      const target = navigationTarget(prompt);
      if (target == null) return null;
      return buildNavigationResult({
        target,
        role,
        date,
        objectName: role === "foreman" ? assignedObject : requestedObject,
        prompt,
      });
    }
    case "timesheet_update": {
      return await invokeAssistantFunction({
        functionName: "ai-operational-draft",
        supabaseUrl,
        publishable,
        authorization,
        companyId,
        objectName: requestedObject || assignedObject,
        date,
        prompt,
      });
    }
    case "task_create": {
      return await invokeAssistantFunction({
        functionName: "ai-action-draft",
        supabaseUrl,
        publishable,
        authorization,
        companyId,
        objectName: requestedObject || assignedObject,
        date,
        prompt,
      });
    }
    case "document_draft": {
      return await invokeAssistantFunction({
        functionName: "ai-document-draft",
        supabaseUrl,
        publishable,
        authorization,
        companyId,
        objectName: requestedObject || assignedObject,
        date,
        prompt,
      });
    }
    case "operational_insight": {
      return await invokeAssistantFunction({
        functionName: "ai-operational-insights",
        supabaseUrl,
        publishable,
        authorization,
        companyId,
        objectName: requestedObject || assignedObject,
        date,
        prompt,
      });
    }
    case "universal_search": {
      return await invokeAssistantFunction({
        functionName: "ai-search",
        supabaseUrl,
        publishable,
        authorization,
        companyId,
        objectName: requestedObject || assignedObject,
        date,
        prompt,
      });
    }
    case "fallback":
      return null;
  }

  // Exhaustive fallback for future intent additions.
  void userId;
  return null;
}

export function semanticResultBody(
  result: DispatchResult,
  route: SemanticRoute,
): DispatchResult {
  if (isBuilderError(result)) return result;
  return {
    status: result.status,
    body: {
      ...result.body,
      ai_used: result.body.ai_used === true || route.source === "llm",
      semantic_route: {
        intent: route.intent,
        subtype: route.subtype,
        confidence: route.confidence,
        source: route.source,
      },
    },
  };
}
