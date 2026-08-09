import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/data/global_voice_context_controller.dart';

void main() {
  setUp(() => GlobalVoiceContextController.clear());

  test('разговорный объект не заменяет выбранный объект приложения', () {
    GlobalVoiceContextController.setObjectName(
      companyId: 'company-1',
      objectName: 'Чона',
    );
    GlobalVoiceContextController.setConversation(
      companyId: 'company-1',
      topic: 'employees',
      mode: 'count',
      date: '2026-08-09',
      prompt: 'сколько сотрудников',
      objectName: 'Мурманск',
    );

    expect(GlobalVoiceContextController.objectNameFor('company-1'), 'Чона');
    expect(
      GlobalVoiceContextController.state.value.conversationObjectName,
      'Мурманск',
    );
  });

  test('репозиторий передаёт и запоминает короткий контекст диалога', () {
    final repository = File(
      'lib/features/ai/data/global_voice_assistant_repository.dart',
    ).readAsStringSync();

    expect(repository, contains("body['conversation_context']"));
    expect(repository, contains('conversationObjectName'));
    expect(repository, contains("data['conversation']"));
    expect(repository, contains('setConversation('));
    expect(repository, contains('clearConversation'));
  });

  test('edge разворачивает короткие продолжения до маршрутизации команды', () {
    final index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();
    final conversation = File(
      'supabase/functions/ai-global-command/conversation_context.ts',
    ).readAsStringSync();

    expect(index, contains('parseGlobalVoiceConversationContext'));
    expect(index, contains('resolveGlobalVoiceConversationPrompt'));
    expect(index, contains('resolvedConversation.inherited'));
    expect(index, contains('conversationContext.objectName'));

    expect(conversation, contains('кто(?:\\s+именно)?'));
    expect(conversation, contains('какие(?:\\s+именно)?'));
    expect(conversation, contains('открой\\s+их'));
    expect(conversation, contains('"кто сотрудники"'));
    expect(conversation, contains('"какие задачи"'));
    expect(conversation, contains('"кто кандидаты"'));
    expect(conversation, contains('"какие заявки снабжения"'));
    expect(conversation, contains('context.date'));
  });

  test('оперативные сводки умеют список кандидатов и снабжения и объект из речи', () {
    final queries = File(
      'supabase/functions/ai-global-command/operational_queries.ts',
    ).readAsStringSync();

    expect(queries, contains('nameMatches(prompt, item.name)'));
    expect(queries, contains('CandidateSummaryRow'));
    expect(queries, contains('ProcurementSummaryRow'));
    expect(queries, contains('query_mode: queryMode'));
    expect(queries, contains('conversation: {'));
    expect(queries, contains('full_name'));
    expect(queries, contains('item.title'));
    expect(queries, contains('action: null'));
  });
}
