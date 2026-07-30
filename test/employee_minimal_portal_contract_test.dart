import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('реальный сотрудник открывает только задачи и историю без чата', () {
    final authGate = File(
      'lib/features/auth/presentation/employee_aware_auth_gate.dart',
    ).readAsStringSync();
    final platform = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final workScreen = File(
      'lib/features/employee/presentation/employee_simple_work_screen.dart',
    ).readAsStringSync();

    expect(authGate, contains('EmployeePlatformWithPassport(profile: profile)'));
    expect(authGate, isNot(contains('EmployeeMainScreen(profile: profile)')));
    expect(platform, contains("label: 'Задачи'"));
    expect(platform, contains("label: 'История задач'"));
    expect(platform, isNot(contains("label: 'Чат'")));
    expect(platform, isNot(contains("label: 'Табель'")));
    expect(platform, isNot(contains("label: 'Выплаты'")));
    expect(platform, isNot(contains("label: 'Паспорт'")));
    expect(workScreen, contains("label: 'Начать смену'"));
    expect(workScreen, contains("label: 'Начать выполнение'"));
  });

  test('начало смены не запускает задачу автоматически', () {
    final repository = File(
      'lib/features/employee/data/employee_work_action_repository.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/employee-work-actions/index.ts',
    ).readAsStringSync();

    expect(repository, contains('static Future<void> startTask(String taskId)'));
    expect(edge, contains('task_id: null'));
    expect(edge, contains('if (action === "start_task")'));
    expect(edge, contains('Сначала начните рабочую смену'));
    expect(edge, contains('Сначала нажмите «Начать выполнение»'));
  });
}
