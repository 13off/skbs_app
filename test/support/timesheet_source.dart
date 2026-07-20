import 'dart:io';

const List<String> _timesheetPaths = <String>[
  'lib/screens/timesheet_screen.dart',
  'lib/screens/timesheet/timesheet_loading.dart',
  'lib/screens/timesheet/timesheet_sync.dart',
  'lib/screens/timesheet/timesheet_actions.dart',
  'lib/screens/timesheet/timesheet_sections.dart',
  'lib/screens/timesheet/timesheet_view.dart',
];

String timesheetSource() {
  return _timesheetPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
