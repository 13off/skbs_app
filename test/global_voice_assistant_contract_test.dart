import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global voice overlay is mounted above the root navigator', () {
    final viewport = File(
      'lib/app/app_scale_viewport.dart',
    ).readAsStringSync();
    final authOverlay = File(
      'lib/features/ai/presentation/global_voice_assistant_auth_overlay.dart',
    ).readAsStringSync();

    expect(viewport, contains('GlobalVoiceAssistantAuthOverlay'));
    expect(authOverlay, contains('UserRepository.fetchCurrentProfile'));
    expect(authOverlay, contains('RolePreviewController.state'));
    expect(authOverlay, contains('GlobalVoiceAssistantLayer'));
  });

  test('global voice uses the existing guarded AI action pipeline', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer.dart',
    ).readAsStringSync();

    expect(layer, contains('recognizeTaskVoice'));
    expect(layer, contains('AiAssistantRepository.request'));
    expect(layer, contains('AiActionExecutionCoordinator.execute'));
    expect(layer, contains('buttonLabel'));
    expect(
      layer,
      contains('перед записью AppСтрой ещё раз покажет точное действие'),
    );
  });

  test('global voice stops after a natural speech pause', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer.dart',
    ).readAsStringSync();

    expect(layer, contains('Duration(milliseconds: 1350)'));
    expect(layer, contains('stopTaskVoiceRecognition'));
  });

  test('role preview cannot execute global voice commands', () {
    final layer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer.dart',
    ).readAsStringSync();

    expect(layer, contains('profile.isRolePreview'));
    expect(
      layer,
      contains('Голосовые команды отключены в предпросмотре роли'),
    );
  });
}
