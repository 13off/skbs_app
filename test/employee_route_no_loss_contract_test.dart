import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('пакет координат остаётся локально до подтверждения сервера', () {
    final runtime = File(
      'lib/features/employee/data/employee_shift_runtime.dart',
    ).readAsStringSync();

    final sendIndex = runtime.indexOf(
      'await EmployeeShiftActionRepository.appendRoutePoints',
    );
    final removeIndex = runtime.indexOf('_pending.removeRange(0, take)');

    expect(sendIndex, greaterThanOrEqualTo(0));
    expect(removeIndex, greaterThan(sendIndex));
    expect(
      runtime,
      contains('Пакет остаётся и в памяти, и в локальном хранилище'),
    );
  });
}
