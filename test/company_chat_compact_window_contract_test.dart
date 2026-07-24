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

  test('workspace contains general, employee and assistant conversations', () {
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
    expect(source, contains("'ИИ-помощник'"));
    expect(source, contains('CompanyChatRepository.fetchThreads()'));
    expect(repository, contains("'get_company_chat_threads'"));
    expect(repository, contains("'p_channel_kind'"));
    expect(repository, contains("'p_peer_user_id'"));
    expect(migration, contains("channel_kind in ('general', 'direct', 'assistant')"));
    expect(migration, contains('get_company_chat_threads'));
  });

  test('photos and files are sent inside the compact workspace', () {
    final source = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();

    expect(source, contains('openFiles()'));
    expect(source, contains('CompanyChatRepository.uploadAttachment('));
    expect(source, contains("'Прикрепить фото или файл'"));
    expect(source, contains('CompanyChatRepository.createSignedAttachmentUrl('));
  });
}
