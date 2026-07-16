import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('foreman gets a separate desktop shift workspace', () {
    final adaptiveHome = source('lib/screens/adaptive_home_screen.dart');
    final home = source(
      'lib/features/foreman/presentation/foreman_desktop_home_screen.dart',
    );
    final repository = source(
      'lib/features/foreman/data/foreman_workspace_repository.dart',
    );

    expect(adaptiveHome, contains('ForemanDesktopHomeScreen'));
    expect(adaptiveHome, contains('profile.isForeman'));
    expect(adaptiveHome, contains('onAddTask'));
    expect(home, contains("title: 'Рабочая смена'"));
    expect(home, contains("label: const Text('Заполнить табель')"));
    expect(home, contains("label: const Text('Добавить задачу')"));
    expect(home, contains('ForemanOverdueTasks'));
    expect(repository, contains('fetchOverdueTasks'));
    expect(repository, contains('fetchTaskMeta'));
    expect(repository, contains(".from('task_photos')"));
    expect(repository, contains(".from('task_assignees')"));
    expect(repository, contains(".inFilter('task_id', ids)"));
    expect(repository, contains(".neq('status', 'Выполнено')"));
  });

  test('foreman desktop tasks have assignee and evidence filters', () {
    final adaptive = source('lib/screens/adaptive_tasks_screen.dart');
    final screen = source(
      'lib/features/foreman/presentation/foreman_desktop_tasks_screen.dart',
    );
    final filters = source(
      'lib/features/foreman/presentation/foreman_task_filters.dart',
    );
    final table = source(
      'lib/features/foreman/presentation/foreman_task_table.dart',
    );

    expect(adaptive, contains('ForemanDesktopTasksScreen'));
    expect(adaptive, contains('profile.isForeman'));
    expect(adaptive, contains('mobile.TasksScreen'));
    expect(screen, contains('TaskEditPolicy.canCreateForDate'));
    expect(screen, contains('TaskRepository.addTaskWithDetails'));
    expect(screen, contains('TaskDetailsScreen'));
    expect(screen, contains('assigneeFilter'));
    expect(filters, contains("labelText: 'Исполнитель'"));
    expect(filters, contains("labelText: 'Объект'"));
    expect(table, contains("SpecialistTableColumn('Исполнители'"));
    expect(table, contains("SpecialistTableColumn('Подтверждение'"));
    expect(table, contains("label: 'Нет фото'"));
    expect(table, contains("label: hasReport ? 'Есть отчёт' : 'Нет отчёта'"));
  });

  test('shell opens quick task creation and keeps bottom navigation', () {
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );
    final timesheet = source('lib/screens/adaptive_timesheet_screen.dart');

    expect(shell, contains('addTaskFromHome'));
    expect(shell, contains('AddTaskScreen'));
    expect(shell, contains('TaskRepository.addTaskWithDetails'));
    expect(shell, contains('onAddTask: addTaskFromHome'));
    expect(shell, contains('ProfessionalBottomNavigation'));
    expect(timesheet, contains('DesktopTimesheetScreen'));
    expect(timesheet, contains('mobile.TimesheetScreen'));
  });
}
