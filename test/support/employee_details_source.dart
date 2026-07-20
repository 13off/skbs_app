import 'dart:io';

String employeeDetailsSource() {
  return <String>[
    'lib/screens/employee_details_screen.dart',
    'lib/screens/employee_details/employee_details_copy.dart',
    'lib/screens/employee_details/employee_details_formatting.dart',
    'lib/screens/employee_details/employee_details_navigation.dart',
    'lib/screens/employee_details/employee_details_sections.dart',
    'lib/screens/employee_details/employee_details_status.dart',
    'lib/screens/employee_details/employee_details_view.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}
