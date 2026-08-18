import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('critical application shell keeps role routes without floating controls', () {
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final chatShell = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();
    final voiceLayer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(mainScreen, contains('PersistentTabShell'));
    expect(chatShell, contains('Widget build(BuildContext context) => child;'));
    expect(voiceLayer, contains('Widget build(BuildContext context) => child;'));
    expect(chatShell, isNot(contains('company-chat-launcher')));
    expect(voiceLayer, isNot(contains('_buildLauncher')));
  });
}
