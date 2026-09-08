import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume retains creator and voiding audit data', () {
    final migration = File(
      'supabase/migrations/20260908103000_add_estimator_manual_volumes.sql',
    ).readAsStringSync();

    expect(migration, contains('created_by uuid not null'));
    expect(migration, contains('created_by_name text not null'));
    expect(migration, contains('created_at timestamptz not null'));
    expect(migration, contains('voided_by uuid'));
    expect(migration, contains('voided_by_name text not null'));
    expect(migration, contains('voided_at timestamptz'));
  });
}
