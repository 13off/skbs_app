import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('absence explanation todo is gated and due at 10:00 Moscow', () {
    final migration = File(
      'supabase/migrations/20260908130500_manager_absence_todo_at_10_msk.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains("v_due_at timestamptz := ((now() at time zone 'Europe/Moscow')::date + time '10:00')"),
    );
    expect(
      migration,
      contains("if v_now_local < v_today + time '10:00' then"),
    );
    expect(migration, isNot(contains("time '08:00'")));
  });

  test('10:00 override preserves current absence exclusions', () {
    final migration = File(
      'supabase/migrations/20260908130500_manager_absence_todo_at_10_msk.sql',
    ).readAsStringSync();

    expect(migration, contains("in ('sick', 'day_off')"));
    expect(migration, contains('coalesce(employee.is_active, false) = true'));
    expect(migration, contains('employee.archived_at is null'));
    expect(migration, contains("'attendance_no_show'"));
    expect(migration, contains("'pending_fine_amount', 10000"));
  });
}
