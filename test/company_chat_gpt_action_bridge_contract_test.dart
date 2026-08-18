import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatGPT action backend remains available while global chat UI is hidden', () {
    final repository = File(
      'lib/features/company_chat/data/company_chat_repository.dart',
    ).readAsStringSync();
    final bridge = File(
      'supabase/functions/company-chat-action-preparer/index.ts',
    ).readAsStringSync();
    final shell = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();

    expect(repository, contains("'company-chat-gpt'"));
    expect(repository, contains("'company-chat-action-preparer'"));
    expect(bridge, contains('/functions/v1/ai-global-command'));
    expect(bridge, contains('confirmation_required'));
    expect(shell, contains('Widget build(BuildContext context) => child;'));
    expect(shell, isNot(contains('CompanyChatScreen(')));
  });
}
