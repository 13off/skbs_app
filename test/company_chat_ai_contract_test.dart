import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('company chat backend stays available while global chat UI is disabled', () {
    final shell = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/company_chat/data/company_chat_repository.dart',
    ).readAsStringSync();

    expect(shell, contains('Widget build(BuildContext context) => child;'));
    expect(shell, isNot(contains('GlobalVoiceActionRouter.execute')));
    expect(repository, contains("'company-chat-gpt'"));
    expect(repository, contains("'get_company_chat_threads'"));
  });
}
