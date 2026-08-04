import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const legacyWorkScreenPath =
      'lib/features/employee/presentation/employee_work_cabinet_screen.dart';
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const homePath =
      'lib/features/employee/presentation/employee_home_screen.dart';
  const workButtonPath =
      'lib/features/employee/presentation/premium_round_work_button.dart';
  const tasksPath =
      'lib/features/employee/presentation/employee_tasks_screen.dart';
  const profilePath = 'lib/screens/profile_screen.dart';
  const repositoryPath =
      'lib/features/employee/data/employee_cabinet_repository.dart';
  const functionPath = 'supabase/functions/employee-cabinet/index.ts';

  test('панель показывает главную начало работы и активные задачи', () {
    final legacy = File(legacyWorkScreenPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();
    final home = File(homePath).readAsStringSync();
    final workButton = File(workButtonPath).readAsStringSync();
    final tasks = File(tasksPath).readAsStringSync();

    expect(wrapper, contains('EmployeeHomeScreen'));
    expect(wrapper, contains('EmployeeTasksScreen'));
    expect(home, contains('PremiumRoundWorkButton('));
    expect(workButton, contains("'Начать работу'"));
    expect(home, contains('runtime.start(employeeId)'));
    expect(tasks, contains("'Активных задач пока нет'"));
    expect(tasks, contains('EmployeeWorkTaskDetailsScreen'));
    expect(legacy, isNot(contains("label: 'Нет активной задачи'")));
  });

  test('режим руководителя использует единый серверный выбор без подписи', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final workActions = File(
      'lib/features/employee/data/employee_work_action_repository.dart',
    ).readAsStringSync();

    expect(workActions, contains('resolveSelection()'));
    expect(workActions, contains("'resolve_selection'"));
    expect(wrapper, isNot(contains('Предпросмотр:')));
    expect(wrapper, contains("actualRole: 'employee'"));
    expect(wrapper, contains('EmployeeHomeScreen'));
    expect(wrapper, contains('EmployeeTasksScreen'));
  });

  test('история задач открывается из профиля отдельно от задач', () {
    final tasks = File(tasksPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();
    final profile = File(profilePath).readAsStringSync();

    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains("label: 'Профиль'"));
    expect(profile, contains("title: 'История задач'"));
    expect(profile, contains('EmployeeWorkTaskHistoryScreen'));
    expect(tasks, contains('EmployeeWorkTaskDetailsScreen'));
    expect(tasks, isNot(contains('showDatePicker(')));
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
  });

  test('панель сотрудника не использует общий редактор прораба', () {
    final tasks = File(tasksPath).readAsStringSync();

    expect(
      tasks,
      isNot(contains("import '../../../screens/task_details_screen.dart'")),
    );
    expect(tasks, isNot(contains('TaskRepository.updateTask')));
    expect(tasks, isNot(contains('saveTaskAssignees')));
    expect(tasks, isNot(contains(".from('tasks')")));
  });
}
