import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global chat and microphone launchers stay disabled', () {
    final chatShell = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();
    final voiceLayer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();
    final voiceAuthOverlay = File(
      'lib/features/ai/presentation/global_voice_assistant_auth_overlay.dart',
    ).readAsStringSync();

    expect(chatShell, contains('Widget build(BuildContext context) => child;'));
    expect(chatShell, isNot(contains('Stack(')));
    expect(chatShell, isNot(contains('CompanyChatScreen(')));

    expect(voiceLayer, contains('Widget build(BuildContext context) => child;'));
    expect(voiceLayer, isNot(contains('_buildLauncher')));
    expect(voiceLayer, isNot(contains('Positioned(')));

    expect(
      voiceAuthOverlay,
      contains('Widget build(BuildContext context) => child;'),
    );
    expect(voiceAuthOverlay, isNot(contains('UserRepository')));
    expect(
      voiceAuthOverlay,
      isNot(contains('EmployeeOperationalAccessRepository')),
    );
  });
}
