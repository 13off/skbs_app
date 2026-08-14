import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manager report signals feed lightweight manager todos', () {
    final migration = File(
      'supabase/migrations/20260814090000_manager_report_todos.sql',
    ).readAsStringSync();

    expect(migration, contains('private.populate_manager_report_todos()'));
    expect(
      migration,
      contains('perform private.populate_manager_report_todos();'),
    );
    expect(migration, contains("'attendance_missing'"));
    expect(migration, contains("'tasks_pending'"));
    expect(migration, contains("'payment_receipts_missing'"));
    expect(migration, contains("'legal_risks'"));
    expect(migration, contains("'legal_documents_expiring'"));
    expect(migration, contains("'milestones_overdue'"));
    expect(migration, contains("source_type = 'manager_report'"));
    expect(migration, contains("set status = 'done'"));
    expect(migration, contains("time '07:55'"));
    expect(migration, contains("time '08:00'"));
  });

  test('report todo sync reuses report data instead of display copy', () {
    final migration = File(
      'supabase/migrations/20260814090000_manager_report_todos.sql',
    ).readAsStringSync();

    expect(migration, contains('private.manager_report_tasks_v2('));
    expect(migration, contains('private.manager_report_people_v2('));
    expect(migration, contains('private.manager_report_finance_v2('));
    expect(migration, contains('private.manager_report_legal('));
    expect(migration, contains('private.manager_report_milestones_v2('));
    expect(migration, isNot(contains('month_amount')));
  });
}
