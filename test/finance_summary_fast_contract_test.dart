import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723250000_get_finance_summary_fast.sql';

  test('home finance card uses one protected aggregate RPC', () {
    final source = File(
      'lib/data/finance_summary_repository.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'static Future<FinanceSummaryData> _loadSummary',
    );

    expect(start, greaterThanOrEqualTo(0));
    final loader = source.substring(start);
    expect(loader, contains("'get_finance_summary_fast'"));
    expect(loader, contains("'p_year'"));
    expect(loader, contains("'p_month'"));
    expect(loader, contains("'p_object_name'"));
    expect(loader, isNot(contains(".from('attendance')")));
    expect(loader, isNot(contains(".from('payments')")));
    expect(loader, isNot(contains('EmployeeRepository.fetchEmployees')));
    expect(loader, isNot(contains('ObjectRepository.fetchObjectNames')));
  });

  test('finance aggregate computes permissions once per active object', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('security definer'));
    expect(sql, contains('authentication required'));
    expect(sql, contains('current_user_company_id()'));
    expect(sql, contains("'accounting.directory.view'"));
    expect(sql, contains("'accounting.attendance.view'"));
    expect(sql, contains("'employees.view'"));
    expect(sql, contains("'attendance.view'"));
    expect(sql, contains("'accounting.payments.view'"));
    expect(sql, contains('object_row.is_active = true'));
  });

  test('finance aggregate preserves period, object and deleted filters', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('object_row.name = v_object_name'));
    expect(sql, contains('attendance.deleted_at is null'));
    expect(sql, contains('payment.deleted_at is null'));
    expect(sql, contains('attendance.work_date between v_first_date and v_last_date'));
    expect(sql, contains('payment.period_year = p_year'));
    expect(sql, contains('payment.period_month = p_month'));
    expect(sql, contains('employee.archived_at is null'));
  });

  test('finance aggregate is authenticated only', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
    expect(sql, contains('v_employee_object_ids'));
    expect(sql, contains('v_attendance_object_ids'));
    expect(sql, contains('v_payment_object_ids'));
  });
}
