import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('редактор задачи разделён по ответственности', () {
    final shell = File(
      'lib/screens/task_details_legacy_screen.dart',
    ).readAsStringSync();
    final loading = File(
      'lib/screens/task_details/task_details_loading.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/screens/task_details/task_details_actions.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/task_details/task_details_sections.dart',
    ).readAsStringSync();
    final view = File(
      'lib/screens/task_details/task_details_view.dart',
    ).readAsStringSync();

    expect(shell, contains("part 'task_details/task_details_loading.dart';"));
    expect(shell, contains("part 'task_details/task_details_actions.dart';"));
    expect(shell, contains("part 'task_details/task_details_sections.dart';"));
    expect(shell, contains("part 'task_details/task_details_view.dart';"));
    expect(shell, contains('class TaskDetailsScreen extends StatefulWidget'));
    expect(shell.split('\n').length, lessThan(150));

    expect(loading, contains('Future<void> loadTaskDetails()'));
    expect(actions, contains('Future<void> addPhotos(String photoStage)'));
    expect(actions, contains('Future<void> saveChanges()'));
    expect(actions, contains('void changeMilestone('));
    expect(sections, contains('Widget buildPhotosBlock('));
    expect(sections, contains('Widget buildMilestoneSection()'));
    expect(view, contains('Widget buildTaskDetailsView()'));
  });

  test('публичный контракт экрана и возврата сохранения сохранён', () {
    final shell = File(
      'lib/screens/task_details_legacy_screen.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/screens/task_details/task_details_actions.dart',
    ).readAsStringSync();

    expect(shell, contains('required this.task'));
    expect(shell, contains('required this.profile'));
    expect(actions, contains("Navigator.pop(context, updatedTask)"));
    expect(actions, contains("Navigator.pop(context, 'delete')"));
    expect(actions, contains('TaskEditPolicy.canDeletePhoto('));
    expect(actions, contains('policy.requireAfterPhotoOnComplete'));
  });
}
