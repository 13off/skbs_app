import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'company chat stays tenant scoped and ChatGPT actions stay confirmed',
    () {
      final migration = File(
        'supabase/migrations/20260724110000_company_chat_with_ai.sql',
      ).readAsStringSync();
      final edge = File(
        'supabase/functions/company-chat-gpt/index.ts',
      ).readAsStringSync();
      final repository = File(
        'lib/features/company_chat/data/company_chat_repository.dart',
      ).readAsStringSync();
      final shell = File(
        'lib/features/company_chat/presentation/company_chat_shell.dart',
      ).readAsStringSync();
      final mainScreen = File(
        'lib/screens/main_screen.dart',
      ).readAsStringSync();

      expect(migration, contains("'company_chat.view'"));
      expect(migration, contains('enable row level security'));
      expect(migration, contains('current_user_company_id()'));
      expect(
        migration,
        contains('company_members_receive_company_chat_broadcasts'),
      );
      expect(migration, contains('company-chat-files'));
      expect(migration, contains('get_company_chat_unread_state'));
      expect(migration, contains('company_chat_messages_ai_reply_uidx'));

      expect(edge, contains('current_user_has_permission'));
      expect(edge, contains('ai.use'));
      expect(edge, contains('company_chat_messages'));
      expect(edge, contains('appstroy_command'));
      expect(edge, contains('/functions/v1/ai-global-command'));
      expect(edge, contains('tool_choice: "auto"'));
      expect(edge, contains('input_mode: "chatgpt"'));
      expect(edge, contains('Authorization'));
      expect(edge, contains('store: false'));

      expect(repository, contains("'company-chat-gpt'"));
      expect(repository, contains('static Future<bool> canUseAi() async => false'));
      expect(shell, contains('GlobalVoiceActionRouter.execute'));
      expect(shell, contains('message.hasAiAction'));
      expect(shell, contains('fetchUnreadState'));
      expect(shell, contains("'ChatGPT'"));
      expect(mainScreen, contains('CompanyChatShell'));
    },
  );
}
