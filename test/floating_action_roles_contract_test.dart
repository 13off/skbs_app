import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'adaptive timesheet routes admin and foreman through the same mobile screen',
    () {
      final adaptive = File(
        'lib/screens/adaptive_timesheet_screen.dart',
      ).readAsStringSync();

      expect(adaptive, contains('profile.isAdmin || profile.isForeman'));
      expect(adaptive, contains('TimesheetScreen('));
    },
  );

  test('mobile save action never uses a hard-coded bottom offset', () {
    final view = File(
      'lib/screens/timesheet/timesheet_view.dart',
    ).readAsStringSync();

    expect(view, contains('bottom: floatingBottom'));
    expect(view, isNot(matches(RegExp(r'bottom:\s*\d+'))));
  });
}
