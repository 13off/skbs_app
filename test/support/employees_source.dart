import 'dart:io';

const List<String> _employeesPaths = <String>[
  'lib/screens/employees_screen.dart',
  'lib/screens/employees/employees_loading.dart',
  'lib/screens/employees/employees_actions.dart',
  'lib/screens/employees/employees_filtering.dart',
  'lib/screens/employees/employees_sections.dart',
  'lib/screens/employees/employees_view.dart',
];

String employeesSource() {
  return _employeesPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
