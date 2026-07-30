import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const workScreenPath =
      'lib/features/employee/presentation/employee_work_cabinet_screen.dart';
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const repositoryPath =
      'lib/features/employee/data/employee_cabinet_repository.dart';
  const functionPath = 'supabase/functions/employee-cabinet/index.ts';

  test('панель показывает активные задачи и начало смены', () {
    final screen = File(workScreenPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(screen, contains('class _ShiftStatusCard'));
    expect(screen, contains("'Активных задач пока нет'"));
    expect(screen, contains("label: 'Начать смену'"));
    expect(screen, contains('EmployeeWorkTaskDetailsScreen'));
    expect(screen, isNot(contains("label: 'Нет активной задачи'")));
    expect(wrapper, contains('EmployeeWorkTasksScreen'));
  });

  test('режим руководителя использует единый серверный выбор без подписи', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final workActions = File(
      'lib/features/employee/data/employee_work_action_repository.dart',
    ).readAsStringSync();

    expect(workActions, contains('resolveSelection()'));
    expect(workActions, contains("'resolve_selection'"));
    expect(wrapper, isNot(contains('Предпросмотр:')));
    expect(wrapper, contains('EmployeeWorkTasksScreen'));
  });

  test('задачи и история разделены на две вкладки', () {
    final screen = File(workScreenPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains("label: 'История задач'"));
    expect(wrapper, contains('EmployeeWorkTaskHistoryScreen'));
    expect(screen, contains('showDatePicker('));
    expect(screen, contains('ExpansionTile('));
    expect(screen, contains('onTap: () => _openTask'));
    expect(screen, isNot(contains('SegmentedButton<bool>')));
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
