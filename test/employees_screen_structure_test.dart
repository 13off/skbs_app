import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/employees_source.dart';

void main() {
  test('экран сотрудников разделён по ответственности', () {
    final shell = File('lib/screens/employees_screen.dart').readAsStringSync();
    final controller = File(
      'lib/screens/employees/employee_directory_controller.dart',
    ).readAsStringSync();
    final loading = File(
      'lib/screens/employees/employees_loading.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/screens/employees/employees_actions.dart',
    ).readAsStringSync();
    final filtering = File(
      'lib/screens/employees/employees_filtering.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/employees/employees_sections.dart',
    ).readAsStringSync();
    final view = File(
      'lib/screens/employees/employees_view.dart',
    ).readAsStringSync();

    expect(shell, contains("part 'employees/employees_loading.dart';"));
    expect(shell, contains("part 'employees/employees_actions.dart';"));
    expect(shell, contains("part 'employees/employees_filtering.dart';"));
    expect(shell, contains("part 'employees/employees_sections.dart';"));
    expect(shell, contains("part 'employees/employees_view.dart';"));
    expect(shell, contains('EmployeeDirectoryController('));
    expect(shell.split('\n').length, lessThan(110));

    expect(loading, contains('directoryController.load('));
    expect(actions, contains('directoryController.downloadSummary()'));
    expect(filtering, contains('directoryController.preparedEmployees('));
    expect(sections, contains('Widget employeeCard'));
    expect(view, contains('Widget buildEmployeesView'));

    expect(controller, contains('AppDataSync.changes.listen'));
    expect(controller, contains('EmployeeRepository.fetchEmployees'));
    expect(
      controller,
      contains('EmployeePrivateSummaryExporter.downloadSummary'),
    );
    expect(controller, contains('restoreScrollOffset('));
  });

  test('контракт сотрудников поиска экспорта и позиции сохранён', () {
    final source = employeesSource();
    for (final fragment in const <String>[
      "label: 'Выплаты'",
      "label: 'Сводка'",
      "label: 'Добавить'",
      'sectionHeader(',
      "'Активные'",
      "'Уволенные'",
      'duplicateKey(Employee employee)',
      'EmployeePrivateSummaryExporter.downloadSummary',
      'PageStorageKey(',
      'scrollController.offset',
      'scrollController.jumpTo(target)',
    ]) {
      expect(source, contains(fragment));
    }
  });
}
