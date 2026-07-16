import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('foreman gets a separate desktop shift workspace', () {
    final router = source('lib/screens/main_screen.dart');
    final platform = source(
      'lib/features/foreman/presentation/foreman_main_screen.dart',
    );
    final home = source(
      'lib/features/foreman/presentation/foreman_desktop_home_screen.dart',
    );
    final repository = source(
      'lib/features/foreman/data/foreman_workspace_repository.dart',
    );

    expect(router, contains('ForemanMainScreen'));
    expect(router, contains('if (profile.isForeman)'));
    expect(platform, contains('desktopBreakpoint = 1050'));
    expect(platform, contains('return premium.MainScreen(profile: profile)'));
    expect(platform, contains('ForemanDesktopHomeScreen'));
    expect(platform, contains('ProfessionalBottomNavigation'));
    expect(platform, contains("label: 'Смена'"));
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
    expect(table, contains("'Нет фото'"));
    expect(table, contains("label: hasReport ? 'Есть отчёт' : 'Нет отчёта'"));
  });

  test('foreman platform opens tasks and keeps mobile fallback', () {
    final platform = source(
      'lib/features/foreman/presentation/foreman_main_screen.dart',
    );
    final timesheet = source('lib/screens/adaptive_timesheet_screen.dart');

    expect(platform, contains('AddTaskScreen'));
    expect(platform, contains('TaskRepository.addTaskWithDetails'));
    expect(platform, contains('TaskDetailsScreen'));
    expect(platform, contains('ForemanDesktopTasksScreen'));
    expect(platform, contains('AdaptiveTimesheetScreen'));
    expect(platform, contains('ProfessionalBottomNavigation'));
    expect(timesheet, contains('DesktopTimesheetScreen'));
    expect(timesheet, contains('return TimesheetScreen('));
  });
}
