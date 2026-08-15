import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancelled absence fines are not exposed as active legal recoveries', () {
    final sql = File(
      'supabase/migrations/20260815091314_legal_workspace_hide_cancelled_fines.sql',
    ).readAsStringSync();

    const activeStatuses = "af.status in ('pending', 'confirmed')";
    expect(activeStatuses.allMatches(sql).length, greaterThanOrEqualTo(2));
  });
}
