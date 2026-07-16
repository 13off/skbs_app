import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('выплата требует объект или все объекты до сотрудника', () {
    final text = source('lib/screens/add_payment_screen.dart');
    expect(text, contains('value: allObjectsScopeValue'));
    expect(
      text.indexOf("labelText: 'Объект'"),
      lessThan(text.indexOf("labelText: 'Сотрудник'")),
    );
    expect(text, contains('filterEmployeesByObject<Employee>'));
    expect(text, contains("'Все объекты'"));
  });

  test('отчёт по выплатам фильтрует сотрудников после объекта', () {
    final sheet = source(
      'lib/features/payments/presentation/widgets/payment_report_sheet.dart',
    );
    final exporter = source(
      'lib/features/payments/data/payment_report_exporter.dart',
    );
    expect(
      sheet.indexOf("labelText: 'Объект'"),
      lessThan(sheet.indexOf("labelText: 'Сотрудник'")),
    );
    expect(sheet, contains('selectedObjectKey == null ? null : submit'));
    expect(sheet, contains('filteredEmployees'));
    expect(exporter, contains('final String? objectName;'));
    expect(exporter, contains('employee.objectNames.any'));
  });

  test('юридические документы и вопросы используют объектный фильтр', () {
    for (final path in <String>[
      'lib/features/legal/presentation/legal_document_editor_part.dart',
      'lib/features/legal/presentation/legal_matter_editor_part.dart',
    ]) {
      final text = source(path);
      expect(
        text.indexOf("labelText: 'Объект'"),
        lessThan(text.indexOf("labelText: 'Сотрудник'")),
      );
      expect(text, contains('value: allObjectsScopeValue'));
      expect(text, contains('employeesForObject'));
      expect(text, contains('employee.objectName'));
    }
  });

  test('бухгалтерские отчёты сначала выбирают объект', () {
    final text = source(
      'lib/features/accounting/presentation/accounting_reports_screen.dart',
    );
    expect(text, contains('Widget objectPanel()'));
    expect(text, contains("child: Text('Все объекты')"));
    expect(text, contains('selectedObjectName: selectedObjectName'));
    expect(text, contains('objectName: selectedObjectName'));
  });
}
