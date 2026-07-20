import 'dart:io';

String periodTimesheetSource() {
  return <String>[
    'lib/screens/period_timesheet_screen.dart',
    'lib/screens/period_timesheet/period_timesheet_export.dart',
    'lib/screens/period_timesheet/period_timesheet_formatting.dart',
    'lib/screens/period_timesheet/period_timesheet_loading.dart',
    'lib/screens/period_timesheet/period_timesheet_period_picker.dart',
    'lib/screens/period_timesheet/period_timesheet_sections.dart',
    'lib/screens/period_timesheet/period_timesheet_view.dart',
    'lib/screens/period_timesheet/period_timesheet_report.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}
