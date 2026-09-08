import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume select policy is tenant scoped', () {
    final migration = File(
      'supabase/migrations/20260908103000_add_estimator_manual_volumes.sql',
    ).readAsStringSync();

    expect(migration, contains('company_id = public.current_user_company_id()'));
    expect(migration, contains('enable row level security'));
  });
}
