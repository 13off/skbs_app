import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'company chat repository uses secure RPC and private broadcast channel',
    () {
      final repository = File(
        'lib/features/company_chat/data/company_chat_repository.dart',
      ).readAsStringSync();

      expect(
        repository,
        contains("opts: const RealtimeChannelConfig(private: true)"),
      );
      expect(repository, contains("event: 'company_chat_changed'"));
      expect(repository, contains("'create_company_chat_message'"));
      expect(repository, contains("'mark_company_chat_read'"));
      expect(repository, contains("'company-chat-ai'"));
      expect(repository, contains('uploadBinary'));
      expect(repository, contains('createSignedUrl'));
    },
  );
}
