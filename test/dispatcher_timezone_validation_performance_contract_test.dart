import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723230000_optimize_dispatcher_timezone_validation.sql';

  test('timezone validation uses the internal timezone lookup', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('pg_catalog.timezone(new.timezone, now())'));
    expect(sql, contains('exception when invalid_parameter_value'));
    expect(sql, isNot(contains('from pg_timezone_names')));
  });

  test('timezone validation keeps the existing error contract', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('Неизвестный часовой пояс: %'));
    expect(sql, contains("nullif(btrim(new.timezone), '') is null"));
    expect(sql, contains('Выбранный объект не найден или отключён'));
    expect(sql, contains('Выберите объект для ежедневной сводки'));
  });

  test('dispatcher settings normalization and audit fields remain intact', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('select distinct value from unnest(new.weekdays)'));
    expect(
      sql,
      contains('select distinct value from unnest(new.recipient_roles)'),
    );
    expect(sql, contains('new.object_name := v_object_name'));
    expect(sql, contains('new.updated_at := now()'));
    expect(sql, contains('new.updated_by := coalesce(auth.uid(), new.updated_by)'));
    expect(sql, contains('security definer'));
  });
}
