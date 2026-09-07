import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manager task report excludes soft-deleted tasks everywhere', () {
    final migration = File(
      'supabase/migrations/20260907155000_fix_manager_report_deleted_tasks.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('create or replace function private.manager_report_tasks_v2'),
    );
    expect(RegExp(r'and t\.deleted_at is null').allMatches(migration).length, 4);
    expect(migration, contains("'pending_items', pending.items"));
  });
}
