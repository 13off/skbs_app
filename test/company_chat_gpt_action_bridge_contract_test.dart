import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('functional ChatGPT requests receive AppStroy confirmation actions', () {
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
    expect(bridge, contains('isFunctionalRequest'));
    expect(bridge, contains('/functions/v1/ai-global-command'));
    expect(bridge, contains('action_ready'));
    expect(bridge, contains('button_label'));
    expect(bridge, contains('confirmation_required'));
    expect(bridge, contains('create_task_draft'));
    expect(bridge, contains('prepare_timesheet_correction'));
    expect(bridge, contains('bulk_timesheet_update'));
    expect(bridge, contains('prepare_payment'));
    expect(bridge, contains('open_screen'));
    expect(shell, contains('message.hasAiAction'));
    expect(shell, contains('action.buttonLabel'));
    expect(shell, contains('GlobalVoiceActionRouter.execute('));
  });
}
