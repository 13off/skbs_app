import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/data/global_voice_assistant_repository.dart';
import 'package:skbs_app/features/ai/data/global_voice_context_controller.dart';

void main() {
  setUp(() {
    GlobalVoiceContextController.clear();
  });

  test('voice context remembers the last successful command and action', () {
    GlobalVoiceContextController.rememberTurn(
      companyId: 'company-1',
      prompt: 'создай заявку на 200 кг арматуры на Мурманск',
      objectName: 'Мурманск',
      date: '2026-08-09',
      resultTitle: 'Заявка снабжения подготовлена',
      resultSummary: 'Мурманск: арматура — 200 кг.',
      action: const <String, dynamic>{
        'id': 'action-1',
        'type': 'create_procurement_request',
      },
    );

    final snapshot = GlobalVoiceContextController.snapshotFor('company-1');
    expect(snapshot, isNotNull);
    expect(snapshot!.lastCommandPrompt, contains('200 кг арматуры'));
    expect(snapshot.lastCommandObjectName, 'Мурманск');
    expect(snapshot.lastCommandDate, '2026-08-09');
    expect(snapshot.lastAction['type'], 'create_procurement_request');
  });

  test('compound clarification keeps commands before and after the missing step', () {
    GlobalVoiceContextController.setClarification(
      companyId: 'company-1',
      prompt: 'создай заявку на снабжение',
      question: 'Назови материал',
      before: const <String>['сколько кандидатов'],
      after: const <String>['создай юридическую задачу проверить договор'],
    );

    final snapshot = GlobalVoiceContextController.snapshotFor('company-1')!;
    expect(snapshot.pendingClarificationBefore, const <String>['сколько кандидатов']);
    expect(
      snapshot.pendingClarificationAfter,
      const <String>['создай юридическую задачу проверить договор'],
    );

    GlobalVoiceContextController.clearClarification(companyId: 'company-1');
    final cleared = GlobalVoiceContextController.snapshotFor('company-1')!;
    expect(cleared.pendingClarificationPrompt, isEmpty);
    expect(cleared.pendingClarificationBefore, isEmpty);
    expect(cleared.pendingClarificationAfter, isEmpty);
  });

  test('affirmative follow-up only requests the established confirmation flow', () {
    expect(
      GlobalVoiceAssistantRepository.shouldExecutePreparedAction('да, подтверждай'),
      isTrue,
    );
    expect(
      GlobalVoiceAssistantRepository.shouldExecutePreparedAction('выполняй'),
      isTrue,
    );
    expect(
      GlobalVoiceAssistantRepository.shouldExecutePreparedAction('создай новую задачу'),
      isFalse,
    );
  });

  test('long conversation source keeps correction replay and safe cancellation contracts', () {
    final repository = File(
      'lib/features/ai/data/global_voice_assistant_repository.dart',
    ).readAsStringSync();
    final dictionary = File(
      'lib/features/voice/app_voice_dictionary.dart',
    ).readAsStringSync();
    final shared = File(
      'supabase/functions/ai-global-command/shared.ts',
    ).readAsStringSync();

    expect(repository, contains('_rewriteCorrection'));
    expect(repository, contains('_rewriteReplay'));
    expect(repository, contains('_stripKnownObject'));
    expect(repository, contains('_objectLikePattern'));
    expect(repository, contains('20\\d{2}-\\d{1,2}-\\d{1,2}'));
    expect(repository, contains('lastCommandPrompt'));
    expect(repository, contains('lastAction'));
    expect(repository.toLowerCase(), contains('оставшиеся'));
    expect(
      repository,
      contains('Изменение данных всё равно требует финального подтверждения'),
    );
    expect(dictionary, contains("'то же самое'"));
    expect(dictionary, contains("'подтверждай'"));
    expect(dictionary, contains("'второй объект'"));
    expect(shared, contains('russianNameStem'));
    expect(shared, contains('nameTokenMatches'));
    expect(shared, contains('leftStem === rightStem'));
  });
}
