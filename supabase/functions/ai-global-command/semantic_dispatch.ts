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
import { type SemanticRoute, semanticPrompt } from "./semantic_router.ts";

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

function queryPrompt(route: SemanticRoute, originalPrompt: string): string {
  const canonical = semanticPrompt(route, "")
    .replace(/^\s+|\s+$/g, "")
    .replace(/^Системная семантическая подсказка:\s*/i, "")
    .replace(/\.$/, "");
  return canonical ? `${canonical}. ${originalPrompt}` : originalPrompt;
}

function procurementStatusPrompt(route: SemanticRoute, originalPrompt: string): string {
  const marker: Record<string, string> = {
    delivered: "доставлено",
    in_delivery: "в доставке",
    ordered: "заказано",
    approved: "согласовано",
    canceled: "отменено",
  };
  const status = marker[route.subtype];
  return status ? `${originalPrompt}. Статус заявки снабжения: ${status}.` : originalPrompt;
}

function legalDecisionPrompt(route: SemanticRoute, originalPrompt: string): string {
  if (route.subtype === "reject") {
    return `${originalPrompt}. Отклони юридический вопрос.`;
  }
  if (route.subtype === "approve") {
    return `${originalPrompt}. Согласуй юридический вопрос.`;
  }
  return originalPrompt;
}

function operationalInsightPrompt(route: SemanticRoute, originalPrompt: string): string {
  const marker: Record<string, string> = {
    absence: "кто не вышел сегодня",
    unpaid: "кому не выплатили задолженность",
    expiring_documents: "у кого истекают документы",
    weekly_report: "сводка за неделю",
  };
  const canonical = marker[route.subtype];
  return canonical ? `${canonical}. ${originalPrompt}` : originalPrompt;
}

function insightConversationTopic(route: SemanticRoute): string {
  switch (route.subtype) {
    case "absence":
      return "absence_today";
    default:
      return "";
  }
}

function attachInsightConversation({
  result,
  route,
  originalPrompt,
  objectName,
  date,
}: {
  result: DispatchResult;
  route: SemanticRoute;
  originalPrompt: string;
  objectName: string;
  date: string;
}): DispatchResult {
  if (isBuilderError(result)) return result;
  const topic = insightConversationTopic(route);
  if (!topic) return result;
  return {
    status: result.status,
    body: {
      ...result.body,
      conversation: {
        topic,
        query_mode: "list",
        object_name: objectName,
        date,
        prompt: originalPrompt,
      },
    },
  };
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
  // Semantic routing decides WHAT the user means. Existing builders still
  // decide WHO/WHERE/WHEN/HOW MUCH from the original phrase and database.
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
        prompt: queryPrompt(route, originalPrompt),
        date,
      });
    }
    case "hr_stage_move": {
      return await buildHrStageMove({
        client,
        companyId,
        role,
        prompt: originalPrompt,
        date,
      });
    }
    case "candidate_responsible": {
      return await buildCandidateResponsible({
        client,
        companyId,
        role,
        prompt: originalPrompt,
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
        prompt: originalPrompt,
        date,
      });
    }
    case "procurement_status": {
      return await buildProcurementStatus({
        client,
        companyId,
        role,
        prompt: procurementStatusPrompt(route, originalPrompt),
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
        prompt: `создай юридический вопрос: ${originalPrompt}`,
        date,
      });
    }
    case "legal_decision": {
      return await buildLegalDecision({
        client,
        companyId,
        role,
        prompt: legalDecisionPrompt(route, originalPrompt),
        date,
      });
    }
    case "timesheet_bulk": {
      return await buildBulkTimesheetResult({
        client,
        companyId,
        role,
        assignedObject,
        requestedObject,
        prompt: originalPrompt,
        date,
      });
    }
    case "navigation": {
      const navigationPrompt = semanticPrompt(route, originalPrompt);
      const target = navigationTarget(navigationPrompt);
      if (target == null) return null;
      return buildNavigationResult({
        target,
        role,
        date,
        objectName: role === "foreman" ? assignedObject : requestedObject,
        prompt: originalPrompt,
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
        prompt: `${originalPrompt} исправь табель смены`,
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
        prompt: `${originalPrompt} создай задачу`,
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
        prompt: originalPrompt,
      });
    }
    case "operational_insight": {
      const objectName = requestedObject || assignedObject;
      const result = await invokeAssistantFunction({
        functionName: "ai-operational-insights",
        supabaseUrl,
        publishable,
        authorization,
        companyId,
        objectName,
        date,
        prompt: operationalInsightPrompt(route, originalPrompt),
      });
      return attachInsightConversation({
        result,
        route,
        originalPrompt,
        objectName,
        date,
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
        prompt: originalPrompt,
      });
    }
    case "fallback":
      return null;
  }

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
