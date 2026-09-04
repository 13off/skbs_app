import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void containsAll(String path, Iterable<String> fragments) {
  final contents = source(path);
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный элемент "$fragment" отсутствует в $path',
    );
  }
}

void main() {
  test('платформа бухгалтера отражает реальный рабочий контур', () {
    containsAll(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
      const [
        'pageCount = 5',
        "label: 'Сегодня'",
        "label: 'Операции'",
        "label: 'Документы'",
        "label: 'Контроль'",
        "label: 'Профиль'",
        'AdaptiveAccountingDashboardScreen(',
        'AdaptiveAccountingOperationsScreen()',
        'AccountingDocumentsScreen()',
        'AccountingControlScreen()',
        'onOpenPayments: () => select(1)',
        'onOpenReports: () => select(3)',
      ],
    );
    final main = source(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    );
    expect(main, isNot(contains("label: 'Отчёты'")));
    expect(main, isNot(contains('AdaptiveAccountingReportsScreen')));

    containsAll(
      'lib/features/accounting/presentation/adaptive_accounting_operations_screen.dart',
      const [
        "('bank', 'Банк'",
        "('expenses', 'Расходы'",
        "('payments', 'Выплаты'",
        'AdaptiveAccountingPaymentsScreen()',
        'fetchBankTransactions(',
        'fetchSnapshot(',
      ],
    );

    containsAll(
      'lib/features/accounting/presentation/accounting_documents_screen.dart',
      const [
        "('purchase', 'Поступления'",
        "('sale', 'Реализация'",
        "('counterparties', 'Контрагенты'",
        "('materials', 'Материалы'",
        'createDocument(',
        'createCounterparty(',
        'createMaterialWriteOff(',
      ],
    );

    containsAll(
      'lib/features/accounting/presentation/accounting_control_screen.dart',
      const [
        "('calendar', 'Календарь'",
        "('checks', 'Проверки'",
        "('osv', 'ОСВ'",
        "('reporting', 'Отчётность'",
        'get_accounting_trial_balance',
        'accounting_journal_entries',
        'accounting_journal_lines',
      ],
    );

    containsAll(
      'lib/features/accounting/presentation/adaptive_accounting_payments_screen.dart',
      const [
        'return const PaymentsScreen();',
        "title: 'Выплаты и расчёты'",
        "label: const Text('Табель и начисления')",
        "label: const Text('Скачать XLSX')",
        'PaymentReportExporter.download(',
        'PeriodTimesheetScreen(',
        'selectedObjectName: objectName',
      ],
    );
  });

  test('новые бухгалтерские данные имеют отдельный репозиторий', () {
    containsAll(
      'lib/features/accounting/data/accounting_workbench_repository.dart',
      const [
        "from('accounting_bank_transactions')",
        "from('accounting_primary_documents')",
        "from('accounting_counterparties')",
        "from('accounting_material_movements')",
        "from('accounting_calendar_tasks')",
        'createBankTransaction(',
        'createDocument(',
        'createCounterparty(',
        'createMaterialWriteOff(',
        'createCalendarTask(',
      ],
    );
  });

  test('реальный бухгалтер получает только бухгалтерские права', () {
    containsAll(
      'supabase/migrations/20260716060000_add_accounting_role_access.sql',
      const [
        "('accountant', 'accounting.directory.view')",
        "('accountant', 'accounting.attendance.view')",
        "('accountant', 'accounting.payments.view')",
        "('accountant', 'accounting.payments.edit')",
        "('accountant', 'accounting.receipts.view')",
        "('accountant', 'accounting.receipts.edit')",
        'employees_select_company_accountant',
        'attendance_select_company_accountant',
        'payments_insert_company_accountant',
        'payment_receipts_storage_insert_company_accountant',
      ],
    );
    final migration = source(
      'supabase/migrations/20260716060000_add_accounting_role_access.sql',
    );
    expect(migration, isNot(contains('employee_private_data')));
    expect(migration, isNot(contains('attendance_insert_company_accountant')));
    expect(migration, isNot(contains('attendance_update_company_accountant')));
  });
}
