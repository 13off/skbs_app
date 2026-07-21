import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/data/ai_assistant_repository.dart';

void main() {
  test('новые команды направляются в операционный сервер', () {
    for (final prompt in const <String>[
      'Добавь сотрудника Иванов Иван на объект Мурманск как бетонщик',
      'Подготовь выплату Иванову 15000 рублей',
      'Найди выплаты без чеков за июль',
      'Открой месячный табель за июль',
      'Сформируй акт выполненных работ за 20.07.2026',
      'Собери пакет документов кандидата Петрова',
    ]) {
      expect(
        AiAssistantRepository.functionNameFor(mode: 'chat', prompt: prompt),
        'ai-operational-draft',
        reason: prompt,
      );
    }
  });

  test('служебная задача по найденной проблеме остаётся обычным черновиком', () {
    expect(
      AiAssistantRepository.functionNameFor(
        mode: 'chat',
        prompt: 'Создай задачу по проблеме: у Иванова отсутствует чек',
      ),
      'ai-action-draft',
    );
  });

  test('операционный сервер проверяет роли и остаётся read only', () {
    final edge = File(
      'supabase/functions/ai-operational-draft/index.ts',
    ).readAsStringSync();

    for (final type in const <String>[
      'create_employee_draft',
      'prepare_payment',
      'find_missing_receipts',
      'open_period_timesheet',
      'prepare_work_act',
      'prepare_candidate_documents',
    ]) {
      expect(edge, contains(type));
    }
    expect(edge, contains('auth.getUser()'));
    expect(edge, contains('.from("company_memberships")'));
    expect(edge, contains('isAccounting'));
    expect(edge, contains('isHr'));
    expect(edge, contains('consent_personal_data'));
    expect(edge, contains('payment_receipts'));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(edge, isNot(contains('.insert(')));
    expect(edge, isNot(contains('.update(')));
    expect(edge, isNot(contains('.upsert(')));
    expect(edge, isNot(contains('.delete(')));
  });

  test('клиент использует подтверждение и обычные рабочие репозитории', () {
    final coordinator = File(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    ).readAsStringSync();
    final employee = File(
      'lib/features/ai/presentation/ai_employee_draft_screen.dart',
    ).readAsStringSync();
    final payment = File(
      'lib/features/ai/presentation/ai_payment_draft_screen.dart',
    ).readAsStringSync();
    final report = File(
      'lib/features/ai/presentation/ai_operational_report_screen.dart',
    ).readAsStringSync();

    expect(coordinator, contains('AiActionConfirmationSheet.show('));
    expect(coordinator, contains("'create_employee_draft'"));
    expect(coordinator, contains("'prepare_payment'"));
    expect(coordinator, contains("'find_missing_receipts'"));
    expect(coordinator, contains("'open_period_timesheet'"));
    expect(coordinator, contains("'prepare_work_act'"));
    expect(coordinator, contains("'prepare_candidate_documents'"));
    expect(coordinator, contains('PeriodTimesheetScreen('));
    expect(coordinator, contains('ActPreviewScreen('));

    expect(employee, contains('EmployeeRepository.addEmployee('));
    expect(employee, contains("'Сохранить сотрудника'"));
    expect(payment, contains('PaymentRepository.addPayment('));
    expect(payment, contains('PaymentReceiptRepository.pickReceiptFiles'));
    expect(payment, contains("'Сохранить выплату'"));
    expect(report, contains('Выплаты без чеков'));
    expect(report, contains("'Пакет кандидата'"));
    expect(report, contains('DocumentTemplateRepository.fetchTemplates'));
    expect(report, contains('PaymentsScreen('));
  });

  test('подтверждение показывает критичные поля новых действий', () {
    final confirmation = File(
      'lib/features/ai/presentation/ai_action_confirmation_sheet.dart',
    ).readAsStringSync();

    expect(confirmation, contains("'Открыть карточку нового сотрудника?'"));
    expect(confirmation, contains("'Открыть черновик выплаты?'"));
    expect(confirmation, contains("add('Сумма'"));
    expect(confirmation, contains("add('Период'"));
    expect(confirmation, contains("add('Получено файлов'"));
    expect(confirmation, contains("'В журнале сохранятся предложение ИИ"));
  });
}
