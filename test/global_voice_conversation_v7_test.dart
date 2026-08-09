import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice remembers an incomplete command for a short clarification', () {
    final context = File(
      'lib/features/ai/data/global_voice_context_controller.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/ai/data/global_voice_assistant_repository.dart',
    ).readAsStringSync();

    expect(context, contains('pendingClarificationPrompt'));
    expect(context, contains('pendingClarificationQuestion'));
    expect(context, contains('setClarification'));
    expect(context, contains('clearClarification'));
    expect(repository, contains('_mergeClarification'));
    expect(repository, contains('Исходную команду повторять не нужно'));
    expect(repository, contains('_needsClarification'));
  });

  test('supabase non-2xx errors can become voice clarifications', () {
    final repository = File(
      'lib/features/ai/data/global_voice_assistant_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('on FunctionException catch (error)'));
    expect(repository, contains('error.status'));
    expect(repository, contains('error.details'));
    expect(repository, contains("details['error']"));
    expect(repository, contains('_rememberClarification'));
  });

  test('explicit multi-step speech is split without splitting ordinary and', () {
    final repository = File(
      'lib/features/ai/data/global_voice_assistant_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('_splitCompoundCommands'));
    expect(repository, contains("replaceAll(RegExp(r'\\s*;\\s*'), '|||')"));
    expect(repository, contains('потом'));
    expect(repository, contains('затем'));
    expect(repository, contains('после\\s+этого'));
    expect(repository, isNot(contains("split(RegExp(r'\\s+и\\s+')")));
  });

  test('multiple write steps become one safe compound action', () {
    final repository = File(
      'lib/features/ai/data/global_voice_assistant_repository.dart',
    ).readAsStringSync();
    final router = File(
      'lib/features/ai/actions/global_voice_action_router.dart',
    ).readAsStringSync();

    expect(repository, contains("type: 'voice_compound_batch'"));
    expect(repository, contains("'actions': actions.map(_actionMap)"));
    expect(repository, contains('confirmationRequired: true'));
    expect(router, contains("action.type == 'voice_compound_batch'"));
    expect(router, contains("step.type == 'voice_compound_batch'"));
    expect(router, contains('final result = await execute('));
    expect(router, contains('Пакет остановлен на шаге'));
  });

  test('compound execution reuses child coordinators and their audit', () {
    final router = File(
      'lib/features/ai/actions/global_voice_action_router.dart',
    ).readAsStringSync();
    final baseCoordinator = File(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    ).readAsStringSync();
    final extendedCoordinator = File(
      'lib/features/ai/actions/global_voice_extended_action_coordinator.dart',
    ).readAsStringSync();

    expect(router, contains('GlobalVoiceWorkflowActionCoordinator.execute'));
    expect(router, contains('GlobalVoiceManagementActionCoordinator.execute'));
    expect(router, contains('GlobalVoiceProfessionalActionCoordinator.execute'));
    expect(router, contains('GlobalVoiceExtendedActionCoordinator.execute'));
    expect(baseCoordinator, contains('AiActionAuditRepository.createProposed'));
    expect(extendedCoordinator, contains('AiActionAuditRepository.createProposed'));
  });
}
