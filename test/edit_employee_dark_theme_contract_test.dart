import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('редактирование сотрудника использует цвета активной темы', () {
    final source = File(
      'lib/screens/edit_employee_screen.dart',
    ).readAsStringSync();

    expect(source, contains('final scheme = Theme.of(context).colorScheme;'));
    expect(source, contains('color: scheme.surfaceContainerHighest'));
    expect(source, contains('Border.all(color: scheme.outlineVariant)'));
    expect(source, contains('color: scheme.onSurface'));
    expect(source, contains('Theme.of(context).colorScheme.error'));

    expect(source, isNot(contains('Colors.grey.shade100')));
    expect(source, isNot(contains('Colors.grey.shade200')));
    expect(source, isNot(contains('TextStyle(color: Colors.red)')));
  });

  test('сохранение сотрудника использует месячную зарплату', () {
    final source = File(
      'lib/screens/edit_employee_screen.dart',
    ).readAsStringSync();

    expect(source, contains('EmployeeRepository.updateEmployee('));
    expect(source, contains('employeeId: employeeId'));
    expect(source, contains('objectName: selectedObjectName'));
    expect(source, contains('monthlySalary: monthlySalary'));
    expect(source, contains("'Зарплата в месяц, ₽'"));
    expect(source, contains("'Сохранить изменения'"));
    expect(source, isNot(contains("'Ставка за смену'")));
  });
}
