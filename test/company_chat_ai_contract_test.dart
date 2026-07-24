import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'company chat is tenant scoped, realtime and AI actions stay confirmed',
    () {
      final migration = File(
        'supabase/migrations/20260724110000_company_chat_with_ai.sql',
      ).readAsStringSync();
      final edge = File(
        'supabase/functions/company-chat-ai/index.ts',
      ).readAsStringSync();
      final screen = File(
        'lib/features/company_chat/presentation/company_chat_screen.dart',
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
      expect(edge, contains('подтверждения пользователя'));
      expect(edge, contains('Authorization'));

      expect(screen, contains('AiActionExecutionCoordinator.execute'));
      expect(screen, contains('ИИ ответит в общий чат'));
      expect(screen, contains('openFiles'));
      expect(screen, contains('Упомянуть сотрудника'));
      expect(shell, contains('fetchUnreadState'));
      expect(mainScreen, contains('CompanyChatShell'));
    },
  );
}
