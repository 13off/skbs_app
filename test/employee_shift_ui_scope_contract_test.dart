import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('рабочая панель сотрудника не показывает табель выплаты паспорт и команду', () {
    final shell = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final work = File(
      'lib/features/employee/presentation/employee_work_cabinet_screen.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      "label: 'Табель'",
      "label: 'Выплаты'",
      "label: 'Документы'",
      "label: 'Профиль'",
      "label: 'Команда'",
      'EmployeeTeamTabScreen',
      'EmployeeProfessionalPassport',
      'paidCurrentMonth',
      'estimatedAccrued',
      'Предварительно начислено',
      'Выплаты и авансы',
    ]) {
      expect('$shell\n$work', isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
