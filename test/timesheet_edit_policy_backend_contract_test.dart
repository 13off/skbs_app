import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timesheet edit policy preserves viewing but guards writes', () {
    final migration = File(
      'supabase/migrations/20260906165000_add_timesheet_edit_window_policy.sql',
    ).readAsStringSync();

    expect(migration, isNot(contains('attendance_select_company_object')));
    expect(
      migration,
      contains('public.current_user_can_edit_attendance_date(work_date, object_id)'),
    );
    expect(migration, contains('p_work_date >= current_date - v_window'));
    expect(migration, contains('if v_window is null then'));
    expect(migration, contains('return true;'));
  });
}
