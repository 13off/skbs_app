import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723210000_optimize_dispatcher_summary_center.sql';

  test('dispatcher summary reads settings before creating defaults', () {
    final sql = File(migrationPath).readAsStringSync();
    final selectIndex = sql.indexOf('select * into v_settings');
    final missingIndex = sql.indexOf('if not found then');
    final insertIndex = sql.indexOf(
      'insert into public.dispatcher_summary_settings',
    );

    expect(selectIndex, greaterThanOrEqualTo(0));
    expect(missingIndex, greaterThan(selectIndex));
    expect(insertIndex, greaterThan(missingIndex));
    expect(sql, isNot(contains('on conflict(company_id) do nothing')));
  });

  test('dispatcher summary keeps authorization and response contract', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('security definer'));
    expect(sql, contains('current_user_company_id()'));
    expect(sql, contains('not public.is_admin()'));
    expect(sql, contains('Недостаточно прав для настроек ИИ-диспетчера'));
    expect(sql, contains("'settings', to_jsonb(v_settings)"));
    expect(sql, contains("'objects', v_objects"));
    expect(sql, contains("'runs', v_runs"));
    expect(sql, contains("'server_time', now()"));
  });

  test('dispatcher summary keeps active objects and last thirty runs', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('object_row.is_active = true'));
    expect(sql, contains('order by object_row.name'));
    expect(sql, contains('order by created_at desc'));
    expect(sql, contains('limit 30'));
    expect(sql, contains("'[]'::jsonb"));
  });
}
