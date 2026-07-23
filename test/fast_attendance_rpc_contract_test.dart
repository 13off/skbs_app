import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all attendance reads use the protected fast RPC', () {
    final source = File(
      'lib/data/attendance_repository.dart',
    ).readAsStringSync();
    expect(source, contains("'get_attendance_rows_fast'"));
    expect(source, contains("'p_start_date'"));
    expect(source, contains("'p_employee_ids'"));
    expect(source, contains("'p_worked_only'"));
    expect(
      source.split(".from('attendance')").length - 1,
      1,
      reason: 'Прямой attendance-запрос должен остаться только для записи',
    );
  });

  test('server RPC keeps company and object authorization', () {
    final sql = File(
      'supabase/migrations/20260723131000_optimize_attendance_read_pipeline.sql',
    ).readAsStringSync();
    expect(sql, contains('security definer'));
    expect(sql, contains('current_user_company_id()'));
    expect(sql, contains("'attendance.view'"));
    expect(sql, contains("'accounting.attendance.view'"));
    expect(sql, contains('authentication required'));
    expect(sql, contains('date range is too large'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
  });

  test('active attendance ranges have dedicated partial indexes', () {
    final sql = File(
      'supabase/migrations/20260723131000_optimize_attendance_read_pipeline.sql',
    ).readAsStringSync();
    expect(sql, contains('attendance_active_company_employee_date_idx'));
    expect(sql, contains('attendance_active_company_object_date_idx'));
    expect(sql, contains('where deleted_at is null'));
  });
}
