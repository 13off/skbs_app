import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restriction targets real foreman role and supports object overrides', () {
    final mobile = File('lib/screens/timesheet_screen.dart').readAsStringSync();
    final desktop = File(
      'lib/screens/desktop_timesheet_screen.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260906165000_add_timesheet_edit_window_policy.sql',
    ).readAsStringSync();

    expect(mobile, contains("widget.profile.actualRole == 'foreman'"));
    expect(desktop, contains("widget.profile.actualRole == 'foreman'"));
    expect(migration, contains('v_has_object_override'));
    expect(migration, contains('policy.object_id = p_object_id'));
    expect(migration, contains("v_role is distinct from 'foreman'"));
  });
}
