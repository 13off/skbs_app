import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all roles receive the stored phone in the prepared position line', () {
    final employee = source('lib/models/employee.dart');
    final repository = source('lib/data/employee_repository.dart');

    expect(repository, contains('position, phone, object_name'));
    expect(employee, contains("final phone = json['phone']"));
    expect(employee, contains('if (phone.trim().isNotEmpty) phone.trim()'));
    expect(employee, contains("join(' • ')"));
    expect(employee, contains('positionWithContact'));
  });

  test('both timesheets display and search the prepared position line', () {
    final mobile = source('lib/screens/timesheet_screen.dart');
    final desktop = source('lib/screens/desktop_timesheet_screen.dart');

    expect(mobile, contains('employee.position'));
    expect(mobile, contains('employee.position.toLowerCase().contains(searchText)'));
    expect(desktop, contains('employee.position'));
    expect(desktop, contains('employee.position.toLowerCase().contains(query)'));
  });

  test('phone visibility has no role restriction', () {
    final employee = source('lib/models/employee.dart');

    expect(employee, isNot(contains('UserRepository')));
    expect(employee, isNot(contains('isForeman')));
    expect(employee, isNot(contains('isAdmin')));
    expect(employee, isNot(contains('isLawyer')));
    expect(employee, isNot(contains('isAccountant')));
  });
}
