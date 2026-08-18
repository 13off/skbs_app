import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy global AI and chat launchers are absent from the application shell', () {
    final chatShell = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();
    final voiceLayer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(chatShell, contains('Widget build(BuildContext context) => child;'));
    expect(chatShell, isNot(contains('company-chat-launcher')));
    expect(voiceLayer, contains('Widget build(BuildContext context) => child;'));
    expect(voiceLayer, isNot(contains('_buildLauncher')));
  });
}
