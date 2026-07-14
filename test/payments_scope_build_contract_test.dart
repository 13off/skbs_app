import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('выплаты учитывают выбранный объект и уволенных сотрудников', () {
    final employees = source('lib/screens/employees_screen.dart');
    final payments = source(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    );

    expect(
      employees,
      contains('selectedObjectName: widget.selectedObjectName'),
    );
    expect(payments, contains('objectName: widget.selectedObjectName'));
    expect(payments, contains('includeFired: true'));
  });

  test('выплаты ограничены выбранным месяцем', () {
    final repository = source('lib/data/attendance_repository.dart');

    expect(repository, contains(".eq('period_year', year)"));
    expect(repository, contains(".eq('period_month', month)"));
  });
}
