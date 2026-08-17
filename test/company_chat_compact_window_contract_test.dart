import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat opens from an icon-only button into a resizable workspace', () {
    final source = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();

    expect(source, contains('bool panelOpen = false'));
    expect(source, contains('class _ChatLauncherButton'));
    expect(source, contains("'Открыть чат'"));
    expect(source, contains('class _ChatWorkspacePanel'));
    expect(source, contains('onPanUpdate: onResize'));
    expect(source, contains('SystemMouseCursors.resizeUpLeftDownRight'));
    expect(source, isNot(contains("'Открыть полный чат'")));
    expect(source, isNot(contains('CompanyChatScreen')));
  });

  test('workspace contains general, employee and ChatGPT conversations', () {
    final source = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/company_chat/data/company_chat_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260724170000_company_chat_threads.sql',
    ).readAsStringSync();

    expect(source, contains("'Общий чат сотрудников'"));
    expect(source, contains("'СОТРУДНИКИ'"));
    expect(source, contains("'ChatGPT'"));
    expect(source, contains("'ChatGPT с доступом к AppСтрой'"));
    expect(source, contains('CompanyChatRepository.fetchThreads()'));
    expect(repository, contains("'get_company_chat_threads'"));
    expect(
      repository,
      contains('.where((value) => value.threadKey.isNotEmpty)'),
    );
    expect(repository, isNot(contains('!value.isAssistant')));
    expect(repository, contains("'p_channel_kind'"));
    expect(repository, contains("'p_peer_user_id'"));
    expect(
      migration,
      contains("channel_kind in ('general', 'direct', 'assistant')"),
    );
    expect(migration, contains('get_company_chat_threads'));
  });

  test('ChatGPT is an AppStroy agent with data tools exports and confirmations', () {
    final source = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/company_chat/data/company_chat_repository.dart',
    ).readAsStringSync();
    final backend = File(
      'supabase/functions/company-chat-gpt/index.ts',
    ).readAsStringSync();

    expect(source, contains('const bool _aiAssistantLocked = false'));
    expect(source, contains('GlobalVoiceActionRouter.execute('));
    expect(source, contains('message.hasAiAction'));
    expect(source, contains('action.buttonLabel'));
    expect(source, contains('isBefore(_chatGptCutover)'));
    expect(repository, contains("'company-chat-gpt'"));
    expect(repository, contains('static Future<bool> canUseAi() async => false'));
    expect(backend, contains('appstroy_command'));
    expect(backend, contains('appstroy_data'));
    expect(backend, contains('appstroy_export'));
    expect(backend, contains('/functions/v1/ai-global-command'));
    expect(backend, contains('tool_choice: "auto"'));
    expect(backend, contains('input_mode: "chatgpt"'));
    expect(backend, contains('voice_compound_batch'));
    expect(backend, contains('отдельного подтверждения в интерфейсе'));
  });

  test('photos and files are sent inside the compact workspace', () {
    final source = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();

    expect(source, contains('openFiles()'));
    expect(source, contains('CompanyChatRepository.uploadAttachment('));
    expect(source, contains("'Прикрепить фото или файл'"));
    expect(
      source,
      contains('CompanyChatRepository.createSignedAttachmentUrl('),
    );
  });

  test('employee platform is never wrapped in company chat', () {
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    const employeeReturn =
        'if (profile.isEmployee) return workVisualScope(content);';
    const chatWrapper = 'CompanyChatShell(';

    expect(mainScreen, contains(employeeReturn));
    expect(mainScreen, contains(chatWrapper));
    expect(
      mainScreen.indexOf(employeeReturn),
      lessThan(mainScreen.indexOf(chatWrapper, mainScreen.indexOf(employeeReturn))),
    );
  });
}
