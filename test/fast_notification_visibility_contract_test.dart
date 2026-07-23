import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723160000_optimize_notification_visibility_policy.sql';

  test('notification visibility computes user context once', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('current_user_visible_notification_ids'));
    expect(sql, contains('with ctx as materialized'));
    expect(sql, contains('current_user_company_id()'));
    expect(sql, contains('current_user_role()'));
    expect(sql, contains('current_admin_notification_roles()'));
    expect(sql, contains('current_admin_notification_event_groups()'));
    expect(sql, contains('accessible_object_names'));
  });

  test('fast visibility keeps the existing role and object rules', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('notification.target_user_id = ctx.user_id'));
    expect(sql, contains("ctx.user_role <> 'foreman'"));
    expect(sql, contains("'dispatcher_summary'"));
    expect(sql, contains('notification.object_name'));
    expect(sql, contains('notification.is_push_only = false'));
  });

  test('RLS uses the protected set based visibility function', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('security definer'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
    expect(sql, contains('drop policy if exists notifications_select_company_role'));
    expect(
      sql,
      contains('select public.current_user_visible_notification_ids()'),
    );
  });
}
