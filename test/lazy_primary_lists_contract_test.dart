import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('AppLazyPage builds only visible work-list rows', () {
    final appPage = source('lib/widgets/app_page.dart');
    expect(appPage, contains('class AppLazyPage'));
    expect(appPage, contains('ListView.builder('));
    expect(appPage, contains('itemBuilder(context, listIndex)'));
  });

  test('mobile tasks preserve exact task taps with lazy rows', () {
    final tasks = source('lib/screens/mobile_tasks_screen.dart');
    expect(tasks, contains('return AppLazyPage('));
    expect(tasks, contains('final task = tasks[index]'));
    expect(tasks, contains('onTap: () => openTaskDetails(task)'));
    expect(tasks, isNot(contains('...tasks.map')));
  });

  test(
    'timesheet payments and employees no longer eagerly build every card',
    () {
      final timesheet = source('lib/screens/timesheet/timesheet_view.dart');
      final payments = source(
        'lib/features/payments/presentation/screens/payments_screen.dart',
      );
      final employees = source('lib/screens/employees/employees_view.dart');
      final sections = source('lib/screens/employees/employees_sections.dart');

      expect(timesheet, contains('ListView.builder('));
      expect(timesheet, isNot(contains('...visibleEmployees.map')));
      expect(payments, contains('ListView.builder('));
      expect(payments, isNot(contains('...visibleRows.map')));
      expect(employees, contains('ListView.builder('));
      expect(sections, isNot(contains('...items.map(employeeCard)')));
    },
  );
}
