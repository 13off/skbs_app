import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile и desktop используют один контроллер сотрудников', () {
    final mobile = <String>[
      'lib/screens/employees_screen.dart',
      'lib/screens/employees/employees_loading.dart',
      'lib/screens/employees/employees_actions.dart',
      'lib/screens/employees/employees_filtering.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final desktop = File(
      'lib/screens/adaptive_employees_screen.dart',
    ).readAsStringSync();

    expect(mobile, contains('EmployeeDirectoryController'));
    expect(desktop, contains('EmployeeDirectoryController'));
    expect(mobile, contains('EmployeeDirectoryLogic.restoreScrollOffset'));
    expect(desktop, contains('EmployeeDirectoryLogic.restoreScrollOffset'));

    for (final source in <String>[mobile, desktop]) {
      expect(source, isNot(contains('AppDataSync.changes.listen')));
      expect(source, isNot(contains('EmployeeRepository.fetchEmployees')));
      expect(
        source,
        isNot(contains('EmployeePrivateSummaryExporter.downloadSummary')),
      );
      expect(source, isNot(contains('WidgetsBinding.instance.addPostFrameCallback')));
    }
  });

  test('контроллер владеет загрузкой, realtime, сводкой и объединением', () {
    final controller = File(
      'lib/screens/employees/employee_directory_controller.dart',
    ).readAsStringSync();

    expect(controller, contains('AppDataSync.changes.listen'));
    expect(controller, contains('EmployeeRepository.fetchEmployees'));
    expect(controller, contains('EmployeePrivateDataRepository.fetchMapByEmployeeIds'));
    expect(controller, contains('EmployeePrivateSummaryExporter.downloadSummary'));
    expect(controller, contains('class EmployeeDirectoryLogic'));
    expect(controller, contains('prepareEmployees('));
    expect(controller, contains('restoreScrollOffset('));
  });
}
