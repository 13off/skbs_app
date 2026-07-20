import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('дублирующиеся бухгалтерские политики объединены', () {
    final migration = File(
      'supabase/migrations/20260720170000_consolidate_accounting_rls.sql',
    ).readAsStringSync();

    expect(migration, contains('attendance_select_company_access'));
    expect(migration, contains('employees_select_company_access'));
    expect(migration, contains('payments_select_company_access'));
    expect(migration, contains('payments_insert_company_access'));
    expect(migration, contains('payments_update_company_access'));
    expect(migration, contains('payments_delete_company_access'));
    expect(migration, contains('payment_receipts_select_company_access'));
    expect(migration, contains('payment_receipts_insert_company_access'));
    expect(migration, contains('payment_receipts_delete_company_access'));
  });

  test('политики сохраняют объектный доступ и бухгалтерские разрешения', () {
    final migration = File(
      'supabase/migrations/20260720170000_consolidate_accounting_rls.sql',
    ).readAsStringSync();

    expect(migration, contains('public.can_access_object(object_name)'));
    expect(
      migration,
      contains("current_user_has_permission('accounting.attendance.view')"),
    );
    expect(
      migration,
      contains("current_user_has_permission('accounting.directory.view')"),
    );
    expect(
      migration,
      contains("current_user_has_permission('accounting.payments.view')"),
    );
    expect(
      migration,
      contains("current_user_has_permission('accounting.payments.edit')"),
    );
    expect(
      migration,
      contains("current_user_has_permission('accounting.receipts.view')"),
    );
    expect(
      migration,
      contains("current_user_has_permission('accounting.receipts.edit')"),
    );
    expect(
      migration,
      contains('company_id = (select public.current_user_company_id())'),
    );
  });
}
