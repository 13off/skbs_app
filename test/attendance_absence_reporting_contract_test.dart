import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attendance distinguishes absence from entirely unfilled timesheet', () {
    final migration = File(
      'supabase/migrations/20260814124500_attendance_absence_reporting.sql',
    ).readAsStringSync();

    expect(migration, contains('private.manager_attendance_snapshot'));
    expect(migration, contains("'absent'"));
    expect(migration, contains("'unfilled_objects'"));
    expect(migration, contains('has_any_attendance = true'));
    expect(migration, contains('coalesce(positive_row.shifts, 0) > 0'));
  });

  test('manager gets noon timesheet reminder and next-day explanation todo', () {
    final migration = File(
      'supabase/migrations/20260814124500_attendance_absence_reporting.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('private.populate_manager_timesheet_unfilled_reminders()'),
    );
    expect(migration, contains("time '12:00'"));
    expect(migration, contains("'Не заполнен табель'"));
    expect(migration, contains('private.populate_manager_absence_todos()'));
    expect(migration, contains("time '08:00'"));
    expect(migration, contains("'Взять объяснительные'"));
  });

  test('old report todo about missing attendance is suppressed', () {
    final migration = File(
      'supabase/migrations/20260814124500_attendance_absence_reporting.sql',
    ).readAsStringSync();

    expect(migration, contains("p_issue_code = 'attendance_missing'"));
    expect(migration, contains('p_count := 0'));
  });

  test('manager report wording is about absence, not empty cells', () {
    final review = File(
      'lib/features/reports/presentation/manager_daily_ai_review.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/features/reports/presentation/manager_report_sections.dart',
    ).readAsStringSync();

    expect(review, contains('Отсутствовали сотрудники'));
    expect(review, contains('Взять объяснительные у отсутствовавших сотрудников.'));
    expect(review, isNot(contains('Нет отметки в табеле у')));
    expect(sections, contains('Табель и посещаемость'));
    expect(sections, contains("label: 'Отсутствовали'"));
    expect(sections, isNot(contains("label: 'Без отметки'")));
  });
}
