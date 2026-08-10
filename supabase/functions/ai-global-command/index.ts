import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

import {
  buildBulkTimesheetResult,
  bulkTimesheetIntent,
} from "./bulk_timesheet.ts";
import {
  parseGlobalVoiceConversationContext,
  resolveGlobalVoiceConversationPrompt,
} from "./conversation_context.ts";
import {
  buildCandidateResponsible,
  buildCreateLegalMatter,
  buildCreateProcurementRequest,
  candidateResponsibleIntent,
  createLegalMatterIntent,
  createProcurementRequestIntent,
} from "./extended_actions.ts";
import { buildGroupReferencedFollowUp } from "./group_reference_followup.ts";
import {
  buildMilestoneManagement,
  buildObjectManagement,
  buildSupplierManagement,
  buildUiSetting,
  milestoneManagementIntent,
  objectManagementIntent,
  supplierManagementIntent,
  uiSettingIntent,
} from "./management_actions.ts";
import {
  buildNavigationResult,
  navigationTarget,
} from "./navigation.ts";
import {
  buildOperationalQuery,
  operationalQueryIntent,
} from "./operational_queries.ts";
import {
  buildHrStageMove,
  buildLegalDecision,
  buildProcurementStatus,
  hrStageMoveIntent,
  legalDecisionIntent,
  procurementStatusIntent,
} from "./professional_actions.ts";
import { buildReferencedFollowUp } from "./reference_followup.ts";
import {
  dispatchSemanticVoice,
  semanticResultBody,
} from "./semantic_dispatch.ts";
import { resolveSemanticVoiceIntent } from "./semantic_router.ts";
import {
  baseDate,
  clean,
  corsHeaders,
  json,
  normalized,
  requestedDate,
} from "./shared.ts";
import {
  buildArchiveRestore,
  buildChatMessage,
  buildEmployeeWorkflow,
  buildFlightWorkflow,
} from "./workflow_actions.ts";
import {
  archiveRestoreIntentGuard,
  chatMessageIntentGuard,
  employeeWorkflowIntentGuard,
  flightWorkflowIntentGuard,
} from "./workflow_intent_guards.ts";

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Метод не поддерживается" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const publishable =
      Deno.env.get("SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
      "";
    const authorization = request.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !publishable || !authorization) {
      return json({ error: "Сервис голосовых команд не настроен" }, 500);
    }

    const client = createClient(supabaseUrl, publishable, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const {
      data: { user },
      error: userError,
    } = await client.auth.getUser();
    if (userError || !user) {
      return json({ error: "Требуется повторный вход" }, 401);
    }

    const input = await request.json().catch(() => ({}));
    const companyId = clean(input.company_id, 80);
    const rawPrompt = clean(input.prompt, 4000);
    const conversationContext = parseGlobalVoiceConversationContext(
      input.conversation_context,
    );
    const resolvedConversation = resolveGlobalVoiceConversationPrompt({
      prompt: rawPrompt,
      context: conversationContext,
    });
    const prompt = resolvedConversation.prompt;
    const selectedObject = clean(input.object_name, 180);
    const requestedObject = selectedObject ||
      (resolvedConversation.inherited ? conversationContext.objectName : "");
    const base = baseDate(input.date);
    if (!companyId || !prompt) {
      return json({ error: "Недостаточно данных запроса" }, 400);
    }

    const { data: profile, error: profileError } = await client
      .from("user_profiles")
      .select("object_name, active_company_id, is_active")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.is_active !== true) {
      return json({ error: "Профиль пользователя недоступен" }, 403);
    }
    if (clean(profile.active_company_id, 80) !== companyId) {
      return json({ error: "Команда работает только с активной компанией" }, 403);
    }

    const { data: membership, error: membershipError } = await client
      .from("company_memberships")
      .select("role")
      .eq("company_id", companyId)
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) {
      return json({ error: "Нет доступа к выбранной компании" }, 403);
    }

    const role = clean(membership.role, 30);
    const assignedObject = clean(profile.object_name, 180);
    const date = requestedDate(prompt, base);

    // v13 only handles explicit group/range references and same-as-yesterday
    // follow-ups. The proven v12 single-reference router stays unchanged below.
    const groupedReference = await buildGroupReferencedFollowUp({
      client,
      companyId,
      role,
      assignedObject,
      prompt: rawPrompt,
      date,
      conversationContext,
    });
    if (groupedReference != null) {
      if ("error" in groupedReference) {
        return json({ error: groupedReference.error }, groupedReference.status);
      }
      return json(groupedReference.body, groupedReference.status);
    }

    // Reference follow-up is deliberately evaluated before ordinary intent
    // parsers. It does not trust client-side entity IDs: the previous visible
    // result is reconstructed from the current company and role, then an
    // ordinal/pronoun such as «им», «второму» or «последнюю» is resolved.
    const referenced = await buildReferencedFollowUp({
      client,
      companyId,
      role,
      assignedObject,
      prompt: rawPrompt,
      date,
      conversationContext,
    });
    if (referenced != null) {
      if ("error" in referenced) {
        return json({ error: referenced.error }, referenced.status);
      }
      return json(referenced.body, referenced.status);
    }

    if (uiSettingIntent(prompt)) {
      const result = buildUiSetting({ prompt, date });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (employeeWorkflowIntentGuard(prompt)) {
      const result = await buildEmployeeWorkflow({
        client,
        companyId,
        role,
        userId: user.id,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (chatMessageIntentGuard(prompt)) {
      const result = await buildChatMessage({
        client,
        companyId,
        role,
        userId: user.id,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (flightWorkflowIntentGuard(prompt)) {
      const result = await buildFlightWorkflow({
        client,
        companyId,
        role,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (archiveRestoreIntentGuard(prompt)) {
      const result = await buildArchiveRestore({
        client,
        companyId,
        role,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (candidateResponsibleIntent(prompt)) {
      const result = await buildCandidateResponsible({
        client,
        companyId,
        role,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (createProcurementRequestIntent(prompt)) {
      const result = await buildCreateProcurementRequest({
        client,
        companyId,
        role,
        assignedObject,
        requestedObject,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (createLegalMatterIntent(prompt)) {
      const result = await buildCreateLegalMatter({
        client,
        companyId,
        role,
        requestedObject,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (operationalQueryIntent(prompt)) {
      const result = await buildOperationalQuery({
        client,
        companyId,
        role,
        assignedObject,
        requestedObject,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    const navigation = navigationTarget(prompt);
    if (navigation != null) {
      const result = buildNavigationResult({
        target: navigation,
        role,
        date,
        objectName: role === "foreman" ? assignedObject : requestedObject,
        prompt,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (objectManagementIntent(prompt)) {
      const result = await buildObjectManagement({
        client,
        companyId,
        role,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (milestoneManagementIntent(prompt)) {
      const result = await buildMilestoneManagement({
        client,
        role,
        assignedObject,
        requestedObject,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (supplierManagementIntent(prompt)) {
      const result = await buildSupplierManagement({
        client,
        companyId,
        role,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (bulkTimesheetIntent(prompt)) {
      const result = await buildBulkTimesheetResult({
        client,
        companyId,
        role,
        assignedObject,
        requestedObject,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (hrStageMoveIntent(prompt)) {
      const result = await buildHrStageMove({
        client,
        companyId,
        role,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (legalDecisionIntent(prompt)) {
      const result = await buildLegalDecision({
        client,
        companyId,
        role,
        prompt,
        date,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    if (procurementStatusIntent(prompt)) {
      const result = await buildProcurementStatus({
        client,
        companyId,
        role,
        prompt,
        date,
        requestedObject,
      });
      if ("error" in result) return json({ error: result.error }, result.status);
      return json(result.body, result.status);
    }

    // Everything above is the established fast and deterministic router.
    // Only a phrase that it did not understand reaches semantic interpretation.
    const semanticValue = normalized(prompt);
    const absenceWrite =
      /(?:постав|отмет|исправ|поправ|измени|сдел).*(?:не выш|не явил|отсутств|прогул)/.test(
        semanticValue,
      ) ||
      /(?:не выш|не явил|отсутств|прогул).*(?:постав|отмет|исправ|поправ|измени|сдел)/.test(
        semanticValue,
      );
    const semanticInput = absenceWrite ? `${prompt} табель смены` : prompt;
    const semanticRoute = await resolveSemanticVoiceIntent({
      prompt: semanticInput,
      role,
      context: {
        topic: conversationContext.topic,
        queryMode: conversationContext.queryMode,
        objectName: requestedObject,
        previousPrompt: conversationContext.prompt,
      },
    });

    if (semanticRoute.intent !== "fallback") {
      const semanticResult = await dispatchSemanticVoice({
        route: semanticRoute,
        client,
        companyId,
        role,
        userId: user.id,
        assignedObject,
        requestedObject,
        date,
        originalPrompt: absenceWrite ? `${prompt} 0 смен` : prompt,
        supabaseUrl,
        publishable,
        authorization,
      });
      if (semanticResult != null) {
        const decorated = semanticResultBody(semanticResult, semanticRoute);
        if ("error" in decorated) {
          return json(
            {
              error: decorated.error,
              semantic_route: {
                intent: semanticRoute.intent,
                subtype: semanticRoute.subtype,
                confidence: semanticRoute.confidence,
                source: semanticRoute.source,
              },
            },
            decorated.status,
          );
        }
        return json(decorated.body, decorated.status);
      }
    }

    return json({ fallback: true });
  } catch (error) {
    console.error("ai-global-command failed", error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
