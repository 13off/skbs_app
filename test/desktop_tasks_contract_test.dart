import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('tasks use desktop table only on wide web screens', () {
    final entry = source('lib/screens/tasks_screen.dart');
    final adaptive = source('lib/screens/adaptive_tasks_screen.dart');
    final mobile = source('lib/screens/mobile_tasks_screen.dart');

    expect(entry, contains('return AdaptiveTasksScreen('));
    expect(adaptive, contains('desktopBreakpoint = 1050'));
    expect(adaptive, contains('kIsWeb && constraints.maxWidth'));
    expect(adaptive, contains('return mobile.TasksScreen('));
    expect(adaptive, contains('return DesktopTasksScreen('));

    expect(mobile, contains('class TasksScreen extends StatefulWidget'));
    expect(mobile, contains('TaskRepository.fetchTasksForDate'));
    expect(mobile, contains('AddTaskScreen('));
    expect(mobile, contains('TaskDetailsScreen('));
    expect(mobile, contains('ActPreviewScreen('));
  });

  test('desktop tasks provide date controls, filters and clickable rows', () {
    final desktop = source('lib/screens/desktop_tasks_screen.dart');

    expect(desktop, contains('BoxConstraints(maxWidth: 1400)'));
    expect(desktop, contains("label: 'Объект'"));
    expect(desktop, contains("label: 'Статус'"));
    expect(desktop, contains("hintText: 'Поиск по работе"));
    expect(desktop, contains("_HeaderText('Статус')"));
    expect(desktop, contains("_HeaderText('Работа')"));
    expect(desktop, contains("_HeaderText('Оси / участок')"));
    expect(desktop, contains("_HeaderText('Объект')"));
    expect(desktop, contains("_HeaderText('Комментарий')"));
    expect(desktop, contains('onTap: () => onOpenTask(task)'));
    expect(desktop, contains('TaskDetailsScreen(task: task'));
    expect(desktop, contains('AddTaskScreen('));
    expect(desktop, contains('ActPreviewScreen('));
    expect(desktop, contains('SingleChildScrollView('));
    expect(desktop, contains('scrollDirection: Axis.horizontal'));
  });
}
