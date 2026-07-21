import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/data/ai_assistant_repository.dart';

void main() {
  test('natural commands route to the operational edge function', () {
    for (final prompt in const <String>[
      'Проверь табель и выплаты за июль',
      'Сверь выплаты и табель за июнь',
      'Сделай общий контроль табеля и чеков',
    ]) {
      expect(
        AiAssistantRepository.functionNameFor(mode: 'chat', prompt: prompt),
        'ai-operational-draft',
        reason: prompt,
      );
    }
  });

  test('unified audit is strictly read only', () {
    final source = File(
      'supabase/functions/ai-operational-draft/operational_audit.ts',
    ).readAsStringSync();

    expect(source, contains('.from("attendance")'));
    expect(source, contains('.from("payments")'));
    expect(source, contains('.from("payment_receipts")'));
    expect(source, contains('duplicate_payment'));
    expect(source, contains('payments_exceed_accrual'));
    expect(source, contains('payment_object_mismatch'));
    expect(source, contains('missing_receipt'));
    expect(source, isNot(contains('.insert(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.upsert(')));
    expect(source, isNot(contains('.delete(')));
    expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
  });

  test('audit requires an accounting-capable role', () {
    final edge = File(
      'supabase/functions/ai-operational-draft/index.ts',
    ).readAsStringSync();

    expect(edge, contains('find_operational_anomalies'));
    expect(edge, contains('roles.has("accounting")'));
    expect(edge, contains('roles.has("accountant")'));
    expect(edge, contains('Выплаты доступны руководителю или бухгалтеру'));
  });

  test('client opens existing timesheet and payments screens', () {
    final coordinator = File(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/ai/presentation/ai_operational_audit_screen.dart',
    ).readAsStringSync();
    final confirmation = File(
      'lib/features/ai/presentation/ai_action_confirmation_sheet.dart',
    ).readAsStringSync();

    expect(coordinator, contains("'find_operational_anomalies'"));
    expect(coordinator, contains('AiOperationalAuditScreen('));
    expect(screen, contains('PeriodTimesheetScreen('));
    expect(screen, contains('PaymentsScreen('));
    expect(screen, contains('Отчёт ничего не исправляет автоматически'));
    expect(confirmation, contains('Открыть контрольный отчёт?'));
    expect(confirmation, contains("add('Критичные'"));
  });
}
