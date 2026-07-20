import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const editorPath =
      'lib/screens/task_details/task_details_editor_screen.dart';
  const legacyPath = 'lib/screens/task_details_legacy_screen.dart';

  test('редактор задачи разделён по ответственности', () {
    final shell = File(editorPath).readAsStringSync();
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

    expect(File(legacyPath).existsSync(), isFalse);
    expect(shell, contains("part 'task_details_loading.dart';"));
    expect(shell, contains("part 'task_details_actions.dart';"));
    expect(shell, contains("part 'task_details_sections.dart';"));
    expect(shell, contains("part 'task_details_view.dart';"));
    expect(shell, contains('class TaskDetailsScreen extends StatefulWidget'));
    expect(shell.split('\n').length, lessThan(150));

    expect(loading, contains("part of 'task_details_editor_screen.dart';"));
    expect(loading, contains('Future<void> loadTaskDetails()'));
    expect(actions, contains('Future<void> addPhotos(String photoStage)'));
    expect(actions, contains('Future<void> saveChanges()'));
    expect(actions, contains('void changeMilestone('));
    expect(sections, contains('Widget buildPhotosBlock('));
    expect(sections, contains('Widget buildMilestoneSection()'));
    expect(view, contains('Widget buildTaskDetailsView()'));
  });

  test('публичный контракт экрана и возврата сохранения сохранён', () {
    final shell = File(editorPath).readAsStringSync();
    final actions = File(
      'lib/screens/task_details/task_details_actions.dart',
    ).readAsStringSync();
    final facade = File('lib/screens/task_details_screen.dart').readAsStringSync();

    expect(shell, contains('required this.task'));
    expect(shell, contains('required this.profile'));
    expect(facade, contains('editor.TaskDetailsScreen'));
    expect(facade, isNot(contains('legacy.TaskDetailsScreen')));
    expect(facade, isNot(contains('task_details_legacy_screen.dart')));
    expect(actions, contains("Navigator.pop(context, updatedTask)"));
    expect(actions, contains("Navigator.pop(context, 'delete')"));
    expect(actions, contains('TaskEditPolicy.canDeletePhoto('));
    expect(actions, contains('policy.requireAfterPhotoOnComplete'));
  });
}
