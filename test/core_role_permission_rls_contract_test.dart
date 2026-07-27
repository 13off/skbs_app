import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core modules use effective company and object permissions', () {
    final migration = File(
      'supabase/migrations/20260722214500_enforce_role_permissions_core_modules.sql',
    ).readAsStringSync();

    expect(migration, contains('current_user_has_object_scope'));
    expect(migration, contains('task_temporal_access_for_user'));
    expect(migration, contains("'tasks.view'"));
    expect(migration, contains("'tasks.create'"));
    expect(migration, contains("'tasks.edit'"));
    expect(migration, contains("'tasks.delete'"));
    expect(migration, contains("'tasks.assignees.manage'"));
    expect(migration, contains("'tasks.photos.manage'"));
    expect(migration, contains("'attendance.view'"));
    expect(migration, contains("'attendance.edit'"));
    expect(migration, contains("'attendance.delete'"));
    expect(migration, contains("'employees.view'"));
    expect(migration, contains("'employees.create'"));
    expect(migration, contains("'employees.edit'"));
    expect(migration, contains("'employees.archive'"));
    expect(migration, contains("'employees.delete'"));
    expect(migration, contains("'objects.view'"));
    expect(migration, contains("'objects.create'"));
    expect(migration, contains("'objects.edit'"));
    expect(migration, contains("'objects.archive'"));
    expect(migration, contains("'objects.delete'"));
    expect(migration, contains("'accounting.payments.view'"));
    expect(migration, contains("'accounting.payments.edit'"));
    expect(migration, contains("'accounting.receipts.view'"));
    expect(migration, contains("'accounting.receipts.edit'"));
    expect(migration, contains("'documents.templates.view'"));
    expect(migration, contains("'documents.templates.edit'"));
    expect(migration, contains("'goals.view'"));
    expect(migration, contains("'goals.edit'"));
    expect(migration, contains("'goals.delete'"));
  });

  test('update guards distinguish editing from archiving', () {
    final migration = File(
      'supabase/migrations/20260722214500_enforce_role_permissions_core_modules.sql',
    ).readAsStringSync();

    expect(migration, contains('guard_employee_permission_update'));
    expect(migration, contains('employees_permission_guard'));
    expect(migration, contains('v_archive_changed'));
    expect(migration, contains('v_other_changed'));
    expect(migration, contains('guard_object_permission_update'));
    expect(migration, contains('objects_permission_guard'));
  });

  test('all replacement policies target authenticated users', () {
    final migration = File(
      'supabase/migrations/20260722214500_enforce_role_permissions_core_modules.sql',
    ).readAsStringSync();

    expect(migration, contains('for select to authenticated'));
    expect(migration, contains('for insert to authenticated'));
    expect(migration, contains('for update to authenticated'));
    expect(migration, contains('for delete to authenticated'));
    expect(
      migration,
      isNot(contains("auth.role() = 'authenticated'")),
    );
  });
}
