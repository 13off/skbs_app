import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('рабочая панель сотрудника остаётся минимальной и без GPS-текста', () {
    final shell = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final work = File(
      'lib/features/employee/presentation/employee_simple_work_screen.dart',
    ).readAsStringSync();
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    for (final forbidden in <String>[
      "label: 'Табель'",
      "label: 'Выплаты'",
      "label: 'Документы'",
      "label: 'Профиль'",
      "label: 'Команда'",
      'EmployeeTeamTabScreen',
      'EmployeeProfessionalPassport',
      'Маршрут записывается',
      'маршрут записывается',
      'точек:',
      'Icons.location_on',
      'Icons.location_off',
      'Icons.gps_fixed',
      'Настроить точку объекта',
    ]) {
      expect('$shell\n$work', isNot(contains(forbidden)), reason: forbidden);
    }

    expect(work, contains("label: 'Начать работу'"));
    expect(work, contains("'Работа идёт'"));
    expect(work, contains("'Завершить рабочий день'"));
    expect(work, contains("label: 'Начать выполнение'"));
    expect(main, contains('if (profile.isEmployee) return content;'));
  });
}
