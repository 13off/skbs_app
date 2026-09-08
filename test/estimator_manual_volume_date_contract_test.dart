import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume cannot be entered for a future date', () {
    final migration = File(
      'supabase/migrations/20260908103000_add_estimator_manual_volumes.sql',
    ).readAsStringSync();

    expect(migration, contains('if p_work_date > current_date then'));
    expect(migration, contains('Дата выполнения не может быть в будущем'));
  });
}
