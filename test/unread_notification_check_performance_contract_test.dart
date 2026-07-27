import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723240000_optimize_unread_notification_check.sql';

  test('unread check reuses the protected visibility helper once', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('visible as materialized'));
    expect(sql, contains('private.current_user_visible_notification_ids()'));
    expect(
      RegExp(r'current_user_visible_notification_ids\(\)').allMatches(sql).length,
      1,
    );
  });

  test('unread check preserves company, object, clear and read filters', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('current_user_company_id()'));
    expect(sql, contains('notification.company_id = ctx.company_id'));
    expect(sql, contains('notification.object_name = ctx.object_name'));
    expect(sql, contains('app_notification_clears'));
    expect(sql, contains("clear_row.object_name = ''"));
    expect(sql, contains('app_notification_reads'));
    expect(sql, contains('read_row.notification_id is null'));
  });

  test('unread check has explicit authenticated-only execution', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('security definer'));
    expect(sql, contains('ctx.user_id is not null'));
    expect(sql, contains('ctx.company_id is not null'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
    expect(sql, contains('limit 1'));
  });
}
