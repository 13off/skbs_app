import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmed no-show has a violation act with 10k fine', () {
    final migration = File(
      'supabase/migrations/20260814130500_add_violation_acts_for_absence_fines.sql',
    ).readAsStringSync();

    expect(migration, contains('public.employee_violation_acts'));
    expect(migration, contains("'absence_fine'"));
    expect(migration, contains("'no_show'"));
    expect(migration, contains("'Невыход на смену'"));
    expect(migration, contains('penalty_amount'));
    expect(migration, contains('10000'));
  });

  test('fine confirmation links payment and violation act', () {
    final migration = File(
      'supabase/migrations/20260814130500_add_violation_acts_for_absence_fines.sql',
    ).readAsStringSync();

    expect(migration, contains('public.confirm_absence_fine'));
    expect(migration, contains("status = 'confirmed'"));
    expect(migration, contains('payment_id = v_payment_id'));
    expect(migration, contains('Штраф по акту'));
    expect(migration, contains('Сначала прикрепите скан объяснительной'));
  });

  test('pending fine UI exposes violation act', () {
    final repository = File(
      'lib/features/payments/data/absence_fine_repository.dart',
    ).readAsStringSync();
    final widget = File(
      'lib/features/payments/presentation/widgets/pending_absence_fines_card.dart',
    ).readAsStringSync();

    expect(repository, contains('get_pending_absence_fines_v2'));
    expect(repository, contains('violationActNumber'));
    expect(widget, contains('Акт о нарушении'));
    expect(widget, contains('Штраф по акту'));
  });
}
