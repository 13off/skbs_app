import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath =
      'lib/features/employee/presentation/employee_home_screen.dart';

  test('геолокация запрашивается только после нажатия начала работы', () {
    final home = File(homePath).readAsStringSync();

    expect(home, isNot(contains('await runtime.preparePermission();')));
    expect(home, contains('await runtime.start(employeeId)'));
    expect(home, contains('startWebWithoutLocation(employeeId)'));
  });

  test('сырая ошибка браузера не показывается как object Object', () {
    final home = File(homePath).readAsStringSync();

    expect(home, contains("normalized == '[object object]'"));
    expect(home, contains("normalized.startsWith('instance of ')"));
    expect(home, contains('Не удалось получить геопозицию'));
    expect(home, contains('PermissionDeniedException'));
    expect(home, contains('LocationServiceDisabledException'));
    expect(home, contains('TimeoutException'));
  });

  test('ошибка геопозиции не содержит обучающей инструкции и не блокирует смену', () {
    final home = File(homePath).readAsStringSync();

    expect(home, contains('EmployeeShiftWebFallbackRepository'));
    expect(home, isNot(contains('На iPhone разрешите геопозицию')));
    expect(home, isNot(contains('Конфиденциальность и безопасность')));
    expect(home, isNot(contains('Службы геолокации')));
  });
}
