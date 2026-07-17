import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('foreman sees employee phones in mobile and desktop timesheets', () {
    final mobile = source('lib/screens/timesheet_screen.dart');
    final desktop = source('lib/screens/desktop_timesheet_screen.dart');
    final repository = source('lib/data/employee_repository.dart');

    expect(repository, contains('position, phone, object_name'));

    expect(mobile, contains('widget.profile.isForeman'));
    expect(mobile, contains('employee.phone.trim()'));
    expect(mobile, contains("join(' • ')"));
    expect(mobile, contains('employee.phone.toLowerCase().contains(searchText)'));

    expect(desktop, contains('showPhone: widget.profile.isForeman'));
    expect(desktop, contains('final bool showPhone;'));
    expect(desktop, contains('employee.phone.trim()'));
    expect(desktop, contains("join(' • ')"));
    expect(desktop, contains('employee.phone.toLowerCase().contains(query)'));
  });

  test('phone remains hidden from non-foreman timesheet views', () {
    final mobile = source('lib/screens/timesheet_screen.dart');
    final desktop = source('lib/screens/desktop_timesheet_screen.dart');

    expect(
      mobile,
      contains('if (widget.profile.isForeman && employee.phone.trim().isNotEmpty)'),
    );
    expect(
      desktop,
      contains('if (showPhone && employee.phone.trim().isNotEmpty)'),
    );
  });
}
