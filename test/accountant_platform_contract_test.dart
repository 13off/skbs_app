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
  test('платформа бухгалтера имеет отдельные вкладки и рабочие экраны', () {
    containsAll(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
      const [
        "label: 'Сегодня'",
        "label: 'Выплаты'",
        "label: 'Отчёты'",
        "label: 'Профиль'",
        'AccountingDashboardScreen(',
        'PaymentsScreen()',
        'AccountingReportsScreen()',
      ],
    );
    containsAll(
      'lib/features/accounting/presentation/accounting_dashboard_screen.dart',
      const [
        "title: 'Сегодня'",
        "'Финансовая сводка'",
        "'Сотрудников с остатком'",
        "'Выплат проведено'",
        "'Выплат без чека'",
        "label: 'Добавить выплату'",
        "label: 'Открыть отчёты'",
      ],
    );
    containsAll(
      'lib/features/accounting/presentation/accounting_reports_screen.dart',
      const [
        "title: 'Отчёты'",
        "title: 'Отчёт по выплатам'",
        "title: 'Табель и начисления'",
        "'Реестр выплат'",
        'PaymentReportExporter.download(',
        'PeriodTimesheetScreen(selectedObjectName: null)',
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
