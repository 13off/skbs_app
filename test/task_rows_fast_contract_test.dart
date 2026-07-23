import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723220000_get_task_rows_fast.sql';

  test('daily task list uses one protected RPC', () {
    final source = File('lib/data/task_repository.dart').readAsStringSync();
    final start = source.indexOf(
      'static Future<List<TaskItemData>> _fetchTasksForDate',
    );
    final end = source.indexOf(
      'static Stream<List<TaskItemData>> watchTasksForDate',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final loader = source.substring(start, end);
    expect(loader, contains("'get_task_rows_fast'"));
    expect(loader, contains("'p_task_date'"));
    expect(loader, contains("'p_object_name'"));
    expect(loader, isNot(contains(".from('tasks')")));
  });

  test('task RPC preserves company, scope and permission checks', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('security definer'));
    expect(sql, contains('authentication required'));
    expect(sql, contains('current_user_company_id()'));
    expect(sql, contains('current_user_has_object_scope'));
    expect(sql, contains("'tasks.view'"));
    expect(sql, contains('task_row.object_id = any(v_allowed_object_ids)'));
  });

  test('task RPC keeps existing day, object and draft filters', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('task_row.deleted_at is null'));
    expect(sql, contains('task_row.is_draft = false'));
    expect(sql, contains('task_row.task_date = p_task_date'));
    expect(sql, contains('task_row.object_name = v_object_name'));
    expect(sql, contains('order by task_row.created_at'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
  });
}
