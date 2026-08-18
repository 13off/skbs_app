import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no redundant floating chat or voice controls remain', () {
    final chatShell = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();
    final voiceLayer = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(chatShell, isNot(contains('company-chat-launcher')));
    expect(chatShell, contains('Widget build(BuildContext context) => child;'));
    expect(voiceLayer, isNot(contains('_buildLauncher')));
    expect(voiceLayer, contains('Widget build(BuildContext context) => child;'));
  });
}
