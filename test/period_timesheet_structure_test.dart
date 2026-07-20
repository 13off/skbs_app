import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('месячный табель разделён по обязанностям', () {
    final screen = File(
      'lib/screens/period_timesheet_screen.dart',
    ).readAsStringSync();

    for (final part in const <String>[
      "part 'period_timesheet/period_timesheet_export.dart';",
      "part 'period_timesheet/period_timesheet_formatting.dart';",
      "part 'period_timesheet/period_timesheet_loading.dart';",
      "part 'period_timesheet/period_timesheet_period_picker.dart';",
      "part 'period_timesheet/period_timesheet_sections.dart';",
      "part 'period_timesheet/period_timesheet_view.dart';",
    ]) {
      expect(screen, contains(part));
    }

    expect(screen, contains('Widget build(BuildContext context) =>'));
    expect(screen, isNot(contains('AttendanceRepository.fetchMonthlyTimesheet')));
    expect(screen, isNot(contains('TimesheetExcelExporter')));
    expect(screen, isNot(contains('showModalBottomSheet')));
    expect(screen, isNot(contains('DataTable(')));
  });

  test('агрегация отчёта не зависит от Flutter и репозиториев', () {
    final report = File(
      'lib/screens/period_timesheet/period_timesheet_report.dart',
    ).readAsStringSync();

    expect(report, contains('class PeriodTimesheetReport'));
    expect(report, contains('collapseDuplicateRows'));
    expect(report, contains('filterRows'));
    expect(report, contains('summarize'));
    expect(report, isNot(contains("package:flutter")));
    expect(report, isNot(contains('AttendanceRepository')));
    expect(report, isNot(contains('setState')));
  });
}
