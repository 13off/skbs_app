import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const workScreenPath =
      'lib/features/employee/presentation/employee_work_cabinet_screen.dart';
  const teamPath =
      'lib/features/employee/presentation/employee_team_tab_screen.dart';
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const repositoryPath =
      'lib/features/employee/data/employee_cabinet_repository.dart';
  const functionPath = 'supabase/functions/employee-cabinet/index.ts';

  test('главная показывает сотрудника и рабочую кнопку задачи', () {
    final screen = File(workScreenPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(screen, contains('class _EmployeeCard'));
    expect(screen, contains("'На сегодня задач нет'"));
    expect(screen, contains("? 'Начать работу'"));
    expect(screen, contains("'Открыть задачу'"));
    expect(screen, isNot(contains("label: 'Нет активной задачи'")));
    expect(wrapper, contains('0: PlatformTabOverride('));
    expect(wrapper, contains('EmployeeWorkHomeScreen'));
  });

  test('режим руководителя использует единый серверный выбор без подписи', () {
    final team = File(teamPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(team, contains('EmployeeWorkActionRepository.resolveSelection()'));
    expect(team, isNot(contains('EmployeeRepository.fetchEmployees(')));
    expect(team, isNot(contains('Предпросмотр:')));
    expect(wrapper, contains('EmployeeWorkHomeScreen'));
  });

  test('список задач разделён по статусу и карточки открываются', () {
    final screen = File(workScreenPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(screen, contains('SegmentedButton<bool>'));
    expect(screen, contains("label: Text('В работе')"));
    expect(screen, contains("label: Text('Выполнено')"));
    expect(screen, contains('onTap: () => _openTask'));
    expect(wrapper, contains('1: PlatformTabOverride('));
    expect(wrapper, contains('EmployeeWorkTasksScreen'));
  });

  test('сотрудник получает фотографии только назначенных ему задач', () {
    final repository = File(repositoryPath).readAsStringSync();
    final function = File(functionPath).readAsStringSync();

    expect(repository, contains('class EmployeeCabinetTaskPhoto'));
    expect(repository, contains('final List<EmployeeCabinetTaskPhoto> photos;'));
    expect(function, contains('.from("task_assignees")'));
    expect(function, contains('.in("employee_id", employeeIds)'));
    expect(function, contains('.from("task_photos")'));
    expect(function, contains('.in("task_id", visibleTaskIds)'));
    expect(function, contains('.createSignedUrls(storagePaths, 60 * 10)'));
  });

  test('панель сотрудника не использует общий редактор прораба', () {
    final screen = File(workScreenPath).readAsStringSync();

    expect(screen, isNot(contains("import '../../../screens/task_details_screen.dart'")));
    expect(screen, isNot(contains('TaskRepository.updateTask')));
    expect(screen, isNot(contains('saveTaskAssignees')));
    expect(screen, isNot(contains(".from('tasks')")));
  });
}
