import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/data/ai_action_audit_repository.dart';

void main() {
  test('разбирает полную запись аудита и точное предложение', () {
    final record = AiActionAuditRecord.fromMap(<String, dynamic>{
      'id': 'audit-1',
      'user_id': 'user-1',
      'action_id': 'action-1',
      'action_type': 'prepare_timesheet_correction',
      'object_name': 'Мурманск',
      'proposal': <String, dynamic>{
        'title': 'Корректировка табеля подготовлена',
        'payload': <String, dynamic>{
          'employee_name': 'Иванов Иван',
          'date': '2026-07-20',
          'shifts': 1,
        },
      },
      'status': 'completed',
      'target_entity_type': 'attendance',
      'target_entity_id': 'employee-1:2026-07-20',
      'created_at': '2026-07-20T10:00:00Z',
      'confirmed_at': '2026-07-20T10:01:00Z',
      'completed_at': '2026-07-20T10:02:00Z',
    }, actorName: 'Илья');

    expect(record.title, 'Корректировка табеля подготовлена');
    expect(record.actorLabel, 'Илья');
    expect(record.payload['employee_name'], 'Иванов Иван');
    expect(record.payload['shifts'], 1);
    expect(record.status, 'completed');
    expect(record.confirmedAt, isNotNull);
    expect(record.completedAt, isNotNull);
  });

  test('история использует RLS-чтение и не меняет аудит напрямую', () {
    final repository = File(
      'lib/features/ai/data/ai_action_audit_repository.dart',
    ).readAsStringSync();
    final history = File(
      'lib/features/ai/presentation/ai_action_history_screen.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/ai/presentation/ai_assistant_shell_screen.dart',
    ).readAsStringSync();

    expect(repository, contains(".from('ai_action_audit')"));
    expect(repository, contains('fetchHistory('));
    expect(repository, contains(".eq('company_id', cleanCompanyId)"));
    expect(repository, contains(".order('created_at', ascending: false)"));
    expect(repository, isNot(contains(".from('ai_action_audit').update")));
    expect(repository, contains("'transition_ai_action_audit'"));

    expect(history, contains("'Журнал действий ИИ'"));
    expect(history, contains("labelText: 'Поиск по журналу'"));
    expect(history, contains("labelText: 'Статус'"));
    expect(history, contains("labelText: 'Действие'"));
    expect(history, contains("'Точное предложение'"));
    expect(history, contains('record.payload.entries'));

    expect(shell, contains('AiActionHistoryScreen(profile: profile)'));
    expect(shell, contains("tooltip: 'Журнал действий ИИ'"));
  });
}
