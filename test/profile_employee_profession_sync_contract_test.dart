import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260801103500_sync_role_professions_with_employees.sql',
  ).readAsStringSync();

  test('linked employee position is copied to role profiles', () {
    expect(
      migration,
      contains('private.sync_employee_profession_to_user_profiles'),
    );
    expect(migration, contains('set profession = v_profession'));
    expect(migration, contains('select cm.user_id'));
    expect(migration, contains('select eal.user_id'));
  });

  test('employee edits refresh the linked profile profession', () {
    expect(
      migration,
      contains('create or replace function private.sync_employee_personal_fields()'),
    );
    expect(
      migration,
      contains('perform private.sync_employee_profession_to_user_profiles('),
    );
  });

  test('company member profession updates the employee card too', () {
    expect(
      migration,
      contains('create or replace function public.update_company_member_access('),
    );
    expect(migration, contains('set position = v_profession'));
    expect(migration, contains("'profession', v_profession"));
  });

  test('existing linked accounts receive canonical non-empty positions', () {
    expect(migration, contains('with canonical_employee as'));
    expect(migration, contains("btrim(coalesce(e.position, '')) <> ''"));
    expect(migration, contains('up.profession is distinct from'));
  });
}
