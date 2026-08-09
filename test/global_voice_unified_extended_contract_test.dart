import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('в приложении остаётся один канонический глобальный voice overlay', () {
    final viewport = File('lib/app/app_scale_viewport.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final authOverlay = File(
      'lib/features/ai/presentation/global_voice_assistant_auth_overlay.dart',
    ).readAsStringSync();

    expect(viewport, contains('GlobalVoiceAssistantAuthOverlay(child: child)'));
    expect(authOverlay, contains('GlobalVoiceAssistantLayerV2('));
    expect(main, isNot(contains('GlobalVoiceRootLayer')));
    expect(
      File('lib/features/voice/presentation/global_voice_root_layer.dart')
          .existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/voice/presentation/global_voice_assistant_layer.dart')
          .existsSync(),
      isFalse,
    );
  });

  test('глобальный голос использует ai-global-command и общий action router', () {
    final repository = File(
      'lib/features/ai/data/global_voice_assistant_repository.dart',
    ).readAsStringSync();
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();
    final router = File(
      'lib/features/ai/actions/global_voice_action_router.dart',
    ).readAsStringSync();

    expect(repository, contains("'ai-global-command'"));
    expect(repository, contains('AiAssistantRepository.request('));
    expect(layer, contains('GlobalVoiceAssistantRepository.request('));
    expect(layer, contains('GlobalVoiceActionRouter.execute('));
    expect(router, contains('GlobalVoiceExtendedActionCoordinator'));
  });

  test('расширенные HR procurement legal voice действия зарегистрированы', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_extended_action_coordinator.dart',
    ).readAsStringSync();
    final server = File(
      'supabase/functions/ai-global-command/extended_actions.ts',
    ).readAsStringSync();
    final index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();

    for (final type in const <String>[
      'assign_candidate_responsible',
      'create_procurement_request',
      'create_legal_matter',
    ]) {
      expect(coordinator, contains("'$type'"));
      expect(server, contains('type: "$type"'));
    }

    expect(index, contains('candidateResponsibleIntent(prompt)'));
    expect(index, contains('createProcurementRequestIntent(prompt)'));
    expect(index, contains('createLegalMatterIntent(prompt)'));
    expect(index, contains('buildCandidateResponsible({'));
    expect(index, contains('buildCreateProcurementRequest({'));
    expect(index, contains('buildCreateLegalMatter({'));
  });

  test('новые write-команды сохраняют подтверждение и журнал ИИ', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_extended_action_coordinator.dart',
    ).readAsStringSync();
    final server = File(
      'supabase/functions/ai-global-command/extended_actions.ts',
    ).readAsStringSync();

    expect(coordinator, contains('AiActionAuditRepository.createProposed('));
    expect(coordinator, contains('AiActionAuditRepository.markConfirmed('));
    expect(coordinator, contains('AiActionAuditRepository.markCompleted('));
    expect(coordinator, contains('final confirmed = await _confirm('));
    expect(server, contains('confirmation_required: true'));
  });
}
