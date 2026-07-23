import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723180000_get_employee_rows_fast.sql';

  test('employee lists use one protected RPC', () {
    final source = File('lib/data/employee_repository.dart').readAsStringSync();
    final start = source.indexOf(
      'static Future<List<Employee>> _loadEmployees',
    );
    final end = source.indexOf(
      'static List<Employee> _employeesFromRows',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final loader = source.substring(start, end);
    expect(loader, contains("'get_employee_rows_fast'"));
    expect(loader, contains("'p_object_name'"));
    expect(loader, contains("'p_include_fired'"));
    expect(loader, isNot(contains(".from('employees')")));
  });

  test('employee RPC preserves company and object authorization', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('security definer'));
    expect(sql, contains('authentication required'));
    expect(sql, contains('current_user_company_id()'));
    expect(sql, contains("'accounting.directory.view'"));
    expect(sql, contains('current_user_has_object_scope'));
    expect(sql, contains("'employees.view'"));
    expect(sql, contains('employee.company_id = v_company_id'));
    expect(sql, contains('employee.object_id = any(v_allowed_object_ids)'));
  });

  test('employee RPC keeps existing filters and is authenticated only', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('employee.archived_at is null'));
    expect(sql, contains('p_include_fired'));
    expect(sql, contains('employee.object_name = v_object_name'));
    expect(sql, contains('order by employee.fio'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
  });
}
