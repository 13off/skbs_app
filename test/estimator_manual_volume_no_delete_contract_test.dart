import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated estimator manual volume path has no destructive delete', () {
    final migration = File(
      'supabase/migrations/20260908103000_add_estimator_manual_volumes.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/features/estimator/data/estimator_manual_volume_repository.dart',
    ).readAsStringSync();

    expect(migration, contains('voided_at timestamptz'));
    expect(migration, contains('void_reason text not null'));
    expect(migration, contains('revoke insert, update, delete'));
    expect(repository, isNot(contains(".delete()")));
    expect(repository, contains("'void_estimator_manual_volume'"));
  });
}
