import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('company chat is visible as a compact floating window', () {
    final source = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();

    expect(source, contains('bool panelOpen = true'));
    expect(source, contains('class _CompactChatPanel'));
    expect(source, contains("'Чат компании'"));
    expect(source, contains("'Сообщений пока нет'"));
    expect(source, contains("'Открыть полный чат'"));
    expect(source, contains('CompanyChatRepository.fetchFeed(limit: 24)'));
    expect(source, contains('CompanyChatRepository.createMessage('));
    expect(source, contains('onCollapse: collapsePanel'));
    expect(source, isNot(contains('if (available)')));
  });
}
