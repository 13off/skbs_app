import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume RPCs are limited to estimator and managers', () {
    final migration = File(
      'supabase/migrations/20260908103000_add_estimator_manual_volumes.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains("v_role not in ('admin', 'developer', 'estimator')"),
    );
    expect(
      migration,
      contains("public.current_user_role() in ('admin', 'developer', 'estimator')"),
    );
  });
}
