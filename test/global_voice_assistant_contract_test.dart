import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global voice overlay is mounted above the root navigator', () {
    final viewport = File('lib/app/app_scale_viewport.dart').readAsStringSync();
    final authOverlay = File(
      'lib/features/ai/presentation/global_voice_assistant_auth_overlay.dart',
    ).readAsStringSync();

    expect(viewport, contains('GlobalVoiceAssistantAuthOverlay'));
    expect(authOverlay, contains('UserRepository.fetchCurrentProfile'));
    expect(authOverlay, contains('RolePreviewController.state'));
    expect(authOverlay, contains('GlobalVoiceAssistantLayerV2'));
  });

  test('global voice uses root navigator and dedicated global router', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(layer, contains('appNavigatorKey.currentContext'));
    expect(layer, contains('recognizeTaskVoice'));
    expect(layer, contains('GlobalVoiceAssistantRepository.request'));
    expect(layer, contains('GlobalVoiceActionRouter.execute'));
    expect(layer, contains('confirmationRequired'));
  });

  test('global voice forms a compact launcher rail above company chat', () {
    final authOverlay = File(
      'lib/features/ai/presentation/global_voice_assistant_auth_overlay.dart',
    ).readAsStringSync();
    final chatShell = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();
    final voiceLayer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(authOverlay, contains('_globalVoiceBottomClearance = 62.0'));
    expect(authOverlay, contains('bottom: _globalVoiceBottomClearance'));
    expect(chatShell, contains('padding.bottom + 92'));
    expect(chatShell, contains('dimension: 54'));
    expect(voiceLayer, contains('constraints.maxHeight - buttonSize - 92'));
  });

  test('global endpoint falls back to the established assistant', () {
    final repository = File(
      'lib/features/ai/data/global_voice_assistant_repository.dart',
    ).readAsStringSync();

    expect(repository, contains("'ai-global-command'"));
    expect(repository, contains("data['fallback'] == true"));
    expect(repository, contains('AiAssistantRepository.request'));
  });

  test('bulk timesheet remains confirmed, audited and one-save based', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_action_execution_coordinator.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/ai-global-command/bulk_timesheet.ts',
    ).readAsStringSync();

    expect(edge, contains('bulk_timesheet_update'));
    expect(edge, contains('default_shifts'));
    expect(edge, contains('affected_count'));
    expect(edge, contains('overrides'));
    expect(coordinator, contains('AiActionAuditRepository.createProposed'));
    expect(coordinator, contains('markConfirmed'));
    expect(coordinator, contains('AttendanceRepository.saveTimesheet'));
    expect(coordinator, contains('Подтвердить и изменить'));
  });

  test('global navigation is permission checked before opening screens', () {
    final router = File(
      'lib/features/ai/actions/global_voice_action_router.dart',
    ).readAsStringSync();
    final edgeNavigation = File(
      'supabase/functions/ai-global-command/navigation.ts',
    ).readAsStringSync();

    expect(router, contains("action.type == 'open_screen'"));
    expect(router, contains('profile.isHr'));
    expect(router, contains('profile.isLawyer'));
    expect(router, contains('profile.isProcurement'));
    expect(router, contains('profile.isAccountant'));
    expect(edgeNavigation, contains('canOpenScreen'));
    expect(edgeNavigation, contains('role === "employee"'));
  });

  test('global voice stops after a natural speech pause', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(layer, contains('Duration(milliseconds: 1350)'));
    expect(layer, contains('stopTaskVoiceRecognition'));
  });

  test('role preview cannot execute global voice commands', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(layer, contains('profile.isRolePreview'));
    expect(
      layer,
      contains('Голосовые команды отключены в предпросмотре роли'),
    );
  });
}
