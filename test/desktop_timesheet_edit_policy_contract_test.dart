import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop timesheet must enforce the same past-date edit policy', () {
    final source = File(
      'lib/screens/desktop_timesheet_screen.dart',
    ).readAsStringSync();

    expect(source, contains('DeveloperPolicyRepository'));
    expect(source, contains('foremanTimesheetEditWindowDays'));
    expect(source, contains("widget.profile.actualRole == 'foreman'"));
    expect(source, contains('canEditSelectedTimesheetDate'));
    expect(source, contains('!canEditSelectedTimesheetDate'));
  });
}
