import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void containsAll(String path, Iterable<String> fragments) {
  final contents = source(path);
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный фрагмент "$fragment" отсутствует в $path',
    );
  }
}

void main() {
  test('прораб редактирует задачу и фото только в день задачи', () {
    containsAll('lib/features/tasks/task_edit_policy.dart', const [
      "DateTime.now().toUtc().add(const Duration(hours: 3))",
      'profile.isAdmin',
      'profile.isForeman',
      'AppState.isSameDay(task.date, operationalToday)',
      'только в день задачи',
    ]);

    containsAll('lib/screens/tasks_screen.dart', const [
      'TaskEditPolicy.canCreateForDate',
      'TaskDetailsScreen(task: task, profile: widget.profile)',
      'Прораб может добавлять задачи только на текущий день',
    ]);

    const taskDetailsPath = 'lib/screens/task_details_screen.dart';
    containsAll(taskDetailsPath, const [
      'final AppUserProfile profile;',
      'bool get canEdit => TaskEditPolicy.canEditTask',
      'Future<void> deletePhoto(TaskPhotoData photo)',
      'TaskRepository.deleteTaskPhoto(photo)',
      "tooltip: 'Удалить фото'",
      'if (widget.profile.isAdmin)',
      'if (!canEdit)',
      'TaskEditPolicy.operationalToday',
    ]);
    expect(
      'enabled: !isSaving && canEdit'.allMatches(source(taskDetailsPath)).length,
      3,
      reason: 'Все три текстовых поля задачи должны блокироваться после дня задачи',
    );

    containsAll('lib/data/task_repository.dart', const [
      'Future<void> deleteTaskPhoto(TaskPhotoData photo)',
      ".from('task_photos')",
      ".remove([photo.storagePath])",
      "'table': 'task_photos'",
    ]);

    containsAll(
      'supabase/migrations/20260716073000_lock_foreman_task_edits_by_day.sql',
      const [
        'current_operational_date()',
        "time zone 'Europe/Moscow'",
        'task_is_mutable_for_user',
        'tasks_update_company_object',
        'task_assignees_delete_company_task',
        'task_photos_delete_company_task',
        'task_photos_storage_delete_company_task',
      ],
    );
  });
}
