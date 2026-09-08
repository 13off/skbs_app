import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume must belong to an object in current company', () {
    final migration = File(
      'supabase/migrations/20260908103000_add_estimator_manual_volumes.sql',
    ).readAsStringSync();

    expect(migration, contains('from public.objects o'));
    expect(migration, contains('o.company_id = v_company_id'));
    expect(migration, contains('Объект не найден в текущей компании'));
  });
}
