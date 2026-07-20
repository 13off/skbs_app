import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const shellPath = 'lib/screens/add_task_screen.dart';

  test('создание задачи разделено по ответственности', () {
    final shell = File(shellPath).readAsStringSync();
    final loading = File(
      'lib/screens/task_create/task_create_loading.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/screens/task_create/task_create_actions.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/task_create/task_create_sections.dart',
    ).readAsStringSync();
    final view = File(
      'lib/screens/task_create/task_create_view.dart',
    ).readAsStringSync();

    expect(shell, contains("part 'task_create/task_create_loading.dart';"));
    expect(shell, contains("part 'task_create/task_create_actions.dart';"));
    expect(shell, contains("part 'task_create/task_create_sections.dart';"));
    expect(shell, contains("part 'task_create/task_create_view.dart';"));
    expect(shell, contains('class TaskCreateDraft'));
    expect(shell, contains('class AddTaskScreen extends StatefulWidget'));
    expect(shell.split('\n').length, lessThan(130));

    expect(loading, contains('Future<void> loadPolicy()'));
    expect(loading, contains('Future<void> loadEmployees()'));
    expect(actions, contains('Future<void> openAssigneesPicker()'));
    expect(actions, contains('Future<void> pickPhotos()'));
    expect(actions, contains('void changeMilestone('));
    expect(actions, contains('void saveTask()'));
    expect(sections, contains('Widget buildAssigneesBlock()'));
    expect(sections, contains('Widget buildPhotosBlock()'));
    expect(view, contains('Widget buildTaskCreateView()'));
  });

  test('публичный результат и ограничения создания сохранены', () {
    final shell = File(shellPath).readAsStringSync();
    final actions = File(
      'lib/screens/task_create/task_create_actions.dart',
    ).readAsStringSync();

    expect(shell, contains('final TaskItemData task;'));
    expect(shell, contains('final List<String> assigneeIds;'));
    expect(shell, contains('final List<TaskPhotoFile> photos;'));
    expect(shell, contains('policy.requireBeforePhoto'));
    expect(shell, contains('policy.minBeforePhotos'));
    expect(shell, contains('initialRequireBeforePhoto'));
    expect(actions, contains('required: requiresBeforePhoto'));
    expect(actions, contains('minimumCount: minimumBeforePhotos'));
    expect(actions, contains('TaskCreateDraft('));
    expect(actions, contains('selectedChecklistItemId'));
  });
}
