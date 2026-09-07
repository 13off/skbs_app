import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('absence explanation todos only keep currently active employees', () {
    final migration = File(
      'supabase/migrations/20260907163500_fix_absence_todo_dismissed_employees.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('create or replace function private.populate_manager_absence_todos()'),
    );
    expect(migration, contains('coalesce(employee.is_active, false) = true'));
    expect(migration, contains('employee.archived_at is null'));
    expect(migration, contains("fine.status = 'pending'"));
    expect(migration, contains("status = 'cancelled'"));
    expect(migration, contains("todo.source_type = 'attendance_no_show'"));
    expect(migration, contains("v_todo.metadata -> 'employees'"));
  });
}
