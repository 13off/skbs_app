import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global edge owns HR legal and procurement professional actions', () {
    final index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();
    final professional = File(
      'supabase/functions/ai-global-command/professional_actions.ts',
    ).readAsStringSync();

    expect(index, contains('hrStageMoveIntent'));
    expect(index, contains('legalDecisionIntent'));
    expect(index, contains('procurementStatusIntent'));
    expect(professional, contains('move_candidate_stage'));
    expect(professional, contains('decide_legal_matter'));
    expect(professional, contains('advance_procurement_status'));
    expect(professional, contains('Не смог однозначно'));
  });

  test('professional writes are role checked confirmed and audited', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_professional_action_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, contains('AiActionAuditRepository.createProposed'));
    expect(coordinator, contains('markConfirmed'));
    expect(coordinator, contains("case 'move_candidate_stage'"));
    expect(coordinator, contains("case 'decide_legal_matter'"));
    expect(coordinator, contains("case 'advance_procurement_status'"));
    expect(coordinator, contains('Подтвердить'));
  });

  test('HR move keeps CRM automations after a confirmed stage change', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_professional_action_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, contains('RecruitmentCrmWorkspaceRepository.bulkMove'));
    expect(coordinator, contains('RecruitmentCrmWorkspaceRepository.runAutomations'));
  });

  test('legal and procurement actions reuse established repositories', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_professional_action_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, contains('LegalRepository.decideMatter'));
    expect(coordinator, contains('ProcurementRepository.setStatus'));
  });

  test('procurement edge refuses skipping workflow stages', () {
    final professional = File(
      'supabase/functions/ai-global-command/professional_actions.ts',
    ).readAsStringSync();

    expect(professional, contains('procurementNext'));
    expect(professional, contains('Нельзя перескочить'));
    expect(professional, contains('desired !== "canceled" && desired !== next'));
  });
}
