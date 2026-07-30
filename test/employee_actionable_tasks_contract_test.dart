import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const dashboardPath =
      'lib/features/employee/presentation/employee_dashboard_screen.dart';
  const tasksPath =
      'lib/features/employee/presentation/employee_actionable_tasks.dart';
  const teamPath =
      'lib/features/employee/presentation/employee_team_tab_screen.dart';
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const repositoryPath =
      'lib/features/employee/data/employee_cabinet_repository.dart';
  const functionPath = 'supabase/functions/employee-cabinet/index.ts';

  test('главная показывает сотрудника и не оставляет мёртвую кнопку', () {
    final dashboard = File(dashboardPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(dashboard, contains('class _EmployeeIdentityCard'));
    expect(dashboard, contains("? 'Сотрудник' : employee.name.trim()"));
    expect(dashboard, contains("'На сегодня задач нет'"));
    expect(dashboard, contains("label: 'Открыть задачу'"));
    expect(dashboard, isNot(contains("label: 'Нет активной задачи'")));
    expect(wrapper, contains('0: PlatformTabOverride('));
    expect(wrapper, contains('EmployeeDashboardScreen'));
  });

  test('режим руководителя подставляет активного сотрудника без подписи предпросмотра', () {
    final dashboard = File(dashboardPath).readAsStringSync();
    final team = File(teamPath).readAsStringSync();

    expect(dashboard, contains('EmployeeRepository.fetchEmployees('));
    expect(dashboard, contains('includeFired: false'));
    expect(dashboard, contains('employee.positionTitle.trim()'));
    expect(team, isNot(contains('Предпросмотр:')));
    expect(team, isNot(contains('seedEmployeeName')));
  });

  test('список задач разделён по статусу и карточки открываются', () {
    final screen = File(tasksPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(screen, contains('SegmentedButton<bool>'));
    expect(screen, contains("label: Text('В работе')"));
    expect(screen, contains("label: Text('Выполнено')"));
    expect(screen, contains('onTap: () => _openTask'));
    expect(wrapper, contains('1: PlatformTabOverride('));
    expect(wrapper, contains('EmployeeActionableTasksScreen'));
  });

  test('сотрудник получает фотографии только назначенных ему задач', () {
    final repository = File(repositoryPath).readAsStringSync();
    final function = File(functionPath).readAsStringSync();

    expect(repository, contains('class EmployeeCabinetTaskPhoto'));
    expect(
      repository,
      contains('final List<EmployeeCabinetTaskPhoto> photos;'),
    );
    expect(function, contains('.from("task_assignees")'));
    expect(function, contains('.in("employee_id", employeeIds)'));
    expect(function, contains('.from("task_photos")'));
    expect(function, contains('.in("task_id", visibleTaskIds)'));
    expect(function, contains('.createSignedUrls(storagePaths, 60 * 10)'));
    expect(function, isNot(contains('input.task_id')));
  });

  test('панель сотрудника не использует общий редактор прораба', () {
    final screen = File(tasksPath).readAsStringSync();

    expect(
      screen,
      isNot(contains("import '../../../screens/task_details_screen.dart'")),
    );
    expect(screen, isNot(contains('TaskRepository.updateTask')));
    expect(screen, isNot(contains('saveTaskAssignees')));
    expect(screen, isNot(contains(".from('tasks')")));
  });
}
