import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/data/ai_assistant_repository.dart';

void main() {
  group('operational insight routing', () {
    test('routes absence questions', () {
      expect(
        AiAssistantRepository.functionNameFor(
          mode: 'chat',
          prompt: 'Кто сегодня не вышел на работу?',
        ),
        'ai-operational-insights',
      );
    });

    test('routes unpaid balance questions', () {
      expect(
        AiAssistantRepository.functionNameFor(
          mode: 'chat',
          prompt: 'Кому еще не выплатили зарплату и какой остаток?',
        ),
        'ai-operational-insights',
      );
    });

    test('routes expiring document questions', () {
      expect(
        AiAssistantRepository.functionNameFor(
          mode: 'chat',
          prompt: 'Какие документы скоро заканчиваются?',
        ),
        'ai-operational-insights',
      );
    });

    test('routes weekly report questions', () {
      expect(
        AiAssistantRepository.functionNameFor(
          mode: 'chat',
          prompt: 'Сделай недельную сводку по объекту',
        ),
        'ai-operational-insights',
      );
    });

    test('keeps write commands in confirmed draft flow', () {
      expect(
        AiAssistantRepository.functionNameFor(
          mode: 'chat',
          prompt: 'Добавь выплату Иванову 10000 рублей',
        ),
        'ai-operational-draft',
      );
      expect(
        AiAssistantRepository.functionNameFor(
          mode: 'chat',
          prompt: 'Поставь задачу Иванову на завтра',
        ),
        'ai-action-draft',
      );
    });
  });

  test('edge function is read-only, JWT-scoped and permission-aware', () {
    final source = File(
      'supabase/functions/ai-operational-insights/index.ts',
    ).readAsStringSync();

    expect(source, contains('client.auth.getUser()'));
    expect(source, contains('current_user_has_permission'));
    expect(source, contains('"ai.use"'));
    expect(source, contains('"accounting.payments.view"'));
    expect(source, contains('"legal.documents.view"'));
    expect(source, contains('absence_today'));
    expect(source, contains('unpaid_employees'));
    expect(source, contains('expiring_documents'));
    expect(source, contains('weekly_site_report'));
    expect(source, contains('.from("attendance")'));
    expect(source, contains('.from("payments")'));
    expect(source, contains('.from("legal_documents")'));
    expect(source, contains('.from("tasks")'));
    expect(source, isNot(contains('.insert(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.delete(')));
    expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
  });
}
