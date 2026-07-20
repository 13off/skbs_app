import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('триггерные функции закрыты от прямого RPC', () {
    final migration = File(
      'supabase/migrations/20260720150000_harden_trigger_privileges_and_foreign_keys.sql',
    ).readAsStringSync();

    expect(migration, contains('audit_developer_constructor_item'));
    expect(migration, contains('audit_dispatcher_summary_settings'));
    expect(migration, contains('validate_developer_custom_setting'));
    expect(migration, contains('validate_developer_reminder_rule'));
    expect(migration, contains('validate_dispatcher_summary_settings'));
    expect(migration, contains('touch_updated_at'));
    expect(migration, contains('from public, anon, authenticated'));
  });

  test('все внешние ключи получают обычные покрывающие индексы', () {
    final migration = File(
      'supabase/migrations/20260720150000_harden_trigger_privileges_and_foreign_keys.sql',
    ).readAsStringSync();

    expect(migration, contains("con.contype = 'f'"));
    expect(migration, contains("n.nspname = 'public'"));
    expect(migration, contains('i.indpred is null'));
    expect(migration, contains('create index if not exists'));
  });
}
