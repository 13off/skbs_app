import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const screenPath =
      'lib/features/employee/presentation/employee_actionable_tasks.dart';
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const repositoryPath =
      'lib/features/employee/data/employee_cabinet_repository.dart';
  const functionPath = 'supabase/functions/employee-cabinet/index.ts';

  test('главная открывает назначенную задачу вместо мёртвой кнопки', () {
    final screen = File(screenPath).readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(
      screen,
      contains(
        "label: task == null ? 'Нет активной задачи' : 'Открыть задачу'",
      ),
    );
    expect(screen, contains('onPressed: task == null'));
    expect(screen, contains('EmployeeTaskDetailsScreen(task: task)'));
    expect(wrapper, contains('0: PlatformTabOverride('));
    expect(wrapper, contains('EmployeeActionableHomeScreen'));
  });

  test('список задач разделён по статусу и карточки открываются', () {
    final screen = File(screenPath).readAsStringSync();
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
    final screen = File(screenPath).readAsStringSync();

    expect(
      screen,
      isNot(contains("import '../../../screens/task_details_screen.dart'")),
    );
    expect(screen, isNot(contains('TaskRepository.updateTask')));
    expect(screen, isNot(contains('saveTaskAssignees')));
    expect(screen, isNot(contains(".from('tasks')")));
  });
}
