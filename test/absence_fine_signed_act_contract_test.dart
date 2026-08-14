import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending fine requires explanation and signed act', () {
    final migration = File(
      'supabase/migrations/20260814143000_fix_absence_fines_with_signed_act.sql',
    ).readAsStringSync();

    expect(migration, contains('act_file_path'));
    expect(migration, contains('absence-fine-acts'));
    expect(migration, contains('Сначала прикрепите скан объяснительной'));
    expect(
      migration,
      contains('Сначала прикрепите подписанный акт о нарушении'),
    );
    expect(migration, contains("'fine'"));
    expect(migration, contains('10000'));
  });

  test('electronic violation act is removed', () {
    final migration = File(
      'supabase/migrations/20260814143000_fix_absence_fines_with_signed_act.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/features/payments/data/absence_fine_repository.dart',
    ).readAsStringSync();

    expect(
      migration,
      contains('drop table if exists public.employee_violation_acts'),
    );
    expect(repository, isNot(contains('violationActNumber')));
    expect(repository, isNot(contains('get_pending_absence_fines_v2')));
  });

  test('inferred absence creates pending fine after attendance snapshot', () {
    final migration = File(
      'supabase/migrations/20260814143000_fix_absence_fines_with_signed_act.sql',
    ).readAsStringSync();

    expect(migration, contains('private.manager_attendance_snapshot'));
    expect(migration, contains('public.absence_fines'));
    expect(migration, contains("'pending'"));
    expect(migration, contains("v_snapshot -> 'absent_items'"));
  });

  test('absence fine security definer RPCs are unavailable to anon', () {
    final migration = File(
      'supabase/migrations/20260814171000_revoke_anonymous_absence_fine_rpcs.sql',
    ).readAsStringSync();

    expect(migration, contains('attach_absence_fine_explanation'));
    expect(migration, contains('can_access_absence_fine_storage'));
    expect(
      RegExp(r'from anon', caseSensitive: false).allMatches(migration),
      hasLength(2),
    );
  });
}
