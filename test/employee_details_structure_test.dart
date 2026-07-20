import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('карточка сотрудника разделена по обязанностям', () {
    final screen = File(
      'lib/screens/employee_details_screen.dart',
    ).readAsStringSync();

    for (final part in const <String>[
      "part 'employee_details/employee_details_copy.dart';",
      "part 'employee_details/employee_details_formatting.dart';",
      "part 'employee_details/employee_details_navigation.dart';",
      "part 'employee_details/employee_details_sections.dart';",
      "part 'employee_details/employee_details_status.dart';",
      "part 'employee_details/employee_details_view.dart';",
    ]) {
      expect(screen, contains(part));
    }

    expect(screen, contains('Widget build(BuildContext context) =>'));
    expect(screen, isNot(contains('Navigator.push')));
    expect(screen, isNot(contains('EmployeeRepository.')));
    expect(screen, isNot(contains('EmployeeArchiveRepository.')));
    expect(screen, isNot(contains('showModalBottomSheet')));
    expect(screen, isNot(contains('showDialog')));
  });

  test('операции сотрудника остаются в специализированных модулях', () {
    final copy = File(
      'lib/screens/employee_details/employee_details_copy.dart',
    ).readAsStringSync();
    final status = File(
      'lib/screens/employee_details/employee_details_status.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/screens/employee_details/employee_details_navigation.dart',
    ).readAsStringSync();

    expect(copy, contains('EmployeeRepository.copyEmployeeToObject'));
    expect(copy, contains("'Скопировать в объект'"));
    expect(status, contains('EmployeeRepository.setEmployeeActive'));
    expect(status, contains('EmployeeArchiveRepository.archiveEmployee'));
    expect(status, contains("'Уволить и архивировать'"));
    expect(navigation, contains('EditEmployeeScreen('));
    expect(navigation, contains('EmployeeTimesheetScreen('));
    expect(navigation, contains('AddPaymentScreen('));
  });
}
