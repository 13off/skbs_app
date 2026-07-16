import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('employees use desktop table only on wide web screens', () {
    final adaptive = source('lib/screens/adaptive_employees_screen.dart');
    final mobile = source('lib/screens/employees_screen.dart');
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expect(adaptive, contains('desktopBreakpoint = 1050'));
    expect(adaptive, contains('kIsWeb && constraints.maxWidth'));
    expect(adaptive, contains('return EmployeesScreen('));
    expect(adaptive, contains('return _DesktopEmployeesScreen('));

    expect(mobile, contains('BoxConstraints(maxWidth: 760)'));
    expect(mobile, contains("'employees-\${widget.selectedObjectName ?? 'all'}'"));

    expect(
      shell,
      contains("import '../../../screens/adaptive_employees_screen.dart';"),
    );
    expect(shell, contains('return AdaptiveEmployeesScreen('));
    expect(shell, isNot(contains("import '../../../screens/employees_screen.dart';")));
  });

  test('desktop employees provide filters, document state and clickable rows', () {
    final adaptive = source('lib/screens/adaptive_employees_screen.dart');
    final desktop = source('lib/screens/desktop_employees_view.dart');

    expect(
      adaptive,
      contains('EmployeePrivateDataRepository.fetchMapByEmployeeIds'),
    );
    expect(adaptive, contains('EmployeeDetailsScreen('));
    expect(adaptive, contains('EmployeePrivateSummaryExporter.downloadSummary'));

    expect(desktop, contains('BoxConstraints(maxWidth: 1400)'));
    expect(desktop, contains("label: 'Объект'"));
    expect(desktop, contains("label: 'Должность'"));
    expect(desktop, contains("label: 'Статус'"));
    expect(desktop, contains("label: 'Документы'"));
    expect(desktop, contains("text: 'Сотрудник'"));
    expect(desktop, contains("text: 'Телефон'"));
    expect(desktop, contains("text: 'Ставка'"));
    expect(desktop, contains("label: 'Готово'"));
    expect(desktop, contains("label: 'Частично'"));
    expect(desktop, contains("label: 'Нет данных'"));
    expect(desktop, contains('onTap: () => onOpenEmployee(entry.$2)'));
    expect(desktop, contains('SingleChildScrollView('));
    expect(desktop, contains('scrollDirection: Axis.horizontal'));
  });
}
