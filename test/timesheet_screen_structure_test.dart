import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/timesheet_source.dart';

void main() {
  test('экран табеля разделён по ответственности', () {
    final shell = File('lib/screens/timesheet_screen.dart').readAsStringSync();
    final loading = File(
      'lib/screens/timesheet/timesheet_loading.dart',
    ).readAsStringSync();
    final sync = File(
      'lib/screens/timesheet/timesheet_sync.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/screens/timesheet/timesheet_actions.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/timesheet/timesheet_sections.dart',
    ).readAsStringSync();
    final view = File(
      'lib/screens/timesheet/timesheet_view.dart',
    ).readAsStringSync();

    expect(shell, contains("part 'timesheet/timesheet_loading.dart';"));
    expect(shell, contains("part 'timesheet/timesheet_sync.dart';"));
    expect(shell, contains("part 'timesheet/timesheet_actions.dart';"));
    expect(shell, contains("part 'timesheet/timesheet_sections.dart';"));
    expect(shell, contains("part 'timesheet/timesheet_view.dart';"));
    expect(shell.split('\n').length, lessThan(120));

    expect(loading, contains('Future<void> loadAttendance'));
    expect(sync, contains('void handleDataChange'));
    expect(actions, contains('Future<void> saveTimesheet'));
    expect(sections, contains('Widget buildEmployeeRow'));
    expect(view, contains('Widget buildTimesheetView'));
  });

  test('пользовательский контракт табеля сохранён', () {
    final source = timesheetSource();
    for (final fragment in const <String>[
      "title: 'Табель'",
      "label: const Text('Отчет')",
      "'Сохранить изменения'",
      "'Сохранить табель'",
      "'Всем 1'",
      "'Всем 0'",
      'child: buildEmployeeRow(employee)',
      'hasPendingRemoteAttendance',
      'hasUnsavedChanges',
      'AttendanceRepository.saveTimesheet',
    ]) {
      expect(source, contains(fragment));
    }
  });
}
