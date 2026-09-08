import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume requires both reason code and explanation', () {
    final migration = File(
      'supabase/migrations/20260908103000_add_estimator_manual_volumes.sql',
    ).readAsStringSync();

    expect(migration, contains('reason_code text not null'));
    expect(migration, contains('reason_comment text not null'));
    expect(migration, contains('Выберите причину ручного ввода'));
    expect(migration, contains('Объясните причину ручного ввода'));
  });
}
