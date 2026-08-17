import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('рабочая панель сотрудника остаётся минимальной и без GPS-текста', () {
    final shell = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final home = File(
      'lib/features/employee/presentation/employee_home_screen.dart',
    ).readAsStringSync();
    final workButton = File(
      'lib/features/employee/presentation/premium_round_work_button.dart',
    ).readAsStringSync();
    final work = File(
      'lib/features/employee/presentation/employee_simple_work_screen.dart',
    ).readAsStringSync();
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    for (final forbidden in <String>[
      "label: 'Табель'",
      "label: 'Выплаты'",
      "label: 'Документы'",
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
      expect(
        '$shell\n$home\n$workButton\n$work',
        isNot(contains(forbidden)),
        reason: forbidden,
      );
    }

    expect(shell, contains("label: 'Главная'"));
    expect(shell, contains("label: 'Задачи'"));
    expect(shell, contains("label: 'Профиль'"));
    expect(home, contains('PremiumRoundWorkButton('));
    expect(workButton, contains("'Начать работу'"));
    expect(workButton, contains("'Завершить работу'"));
    expect(
      workButton,
      contains("'Работа идёт с \${formatTime(widget.startedAt!)}'"),
    );
    expect(home, isNot(contains('FilledButton.tonalIcon(')));
    expect(work, contains("label: 'Начать выполнение'"));
    expect(
      main,
      contains('if (profile.isEmployee) return workVisualScope(content);'),
    );
  });
}
