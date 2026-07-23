import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723190000_add_permission_foreign_key_indexes.sql';

  test('permission matrix foreign keys have covering indexes', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(
      sql,
      contains('company_role_permission_overrides_permission_code_idx'),
    );
    expect(sql, contains('(permission_code)'));
    expect(sql, contains('company_role_permission_overrides_updated_by_idx'));
    expect(sql, contains('(updated_by)'));
    expect(sql, contains('object_role_permission_overrides_object_id_idx'));
    expect(sql, contains('(object_id)'));
    expect(sql, contains('object_role_permission_overrides_permission_code_idx'));
    expect(sql, contains('object_role_permission_overrides_updated_by_idx'));
    expect(sql, contains('role_permission_audit_object_id_idx'));
  });

  test('nullable audit relations use partial indexes', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(
      RegExp(r'updated_by\)\s+where updated_by is not null;', multiLine: true)
          .allMatches(sql)
          .length,
      2,
    );
    expect(
      sql,
      contains('role_permission_audit (object_id)\n  where object_id is not null'),
    );
  });

  test('index hardening is additive only', () {
    final sql = File(migrationPath).readAsStringSync().toLowerCase();

    expect(sql, isNot(contains('drop index')));
    expect(sql, isNot(contains('drop constraint')));
    expect(sql, isNot(contains('alter table')));
    expect(RegExp(r'create index if not exists').allMatches(sql).length, 6);
  });
}
