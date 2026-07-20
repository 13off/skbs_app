import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/task_details_source.dart';

String source(String path) => File(path).readAsStringSync();

void containsAllText(
  String label,
  String contents,
  Iterable<String> fragments,
) {
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный фрагмент "$fragment" отсутствует в $label',
    );
  }
}

void containsAll(String path, Iterable<String> fragments) {
  containsAllText(path, source(path), fragments);
}

void main() {
  test('прораб по умолчанию редактирует сегодня, а объект меняет срок и права', () {
    containsAll('lib/features/tasks/task_edit_policy.dart', const [
      "DateTime.now().toUtc().add(const Duration(hours: 3))",
      'profile.isAdmin',
      'profile.isForeman',
      'AppState.isSameDay(taskDate, operationalToday)',
      'policy.foremanCanEditPastTasks',
      'policy.editWindowDays',
      'policy.foremanCanEditDate',
      'policy.foremanCanEditAxesWork',
      'policy.foremanCanEditAssignees',
      'policy.foremanCanEditStatus',
      'policy.foremanCanDeleteTask',
    ]);

    containsAll('lib/screens/tasks_screen.dart', const [
      'TaskEditPolicy.canCreateForDate',
      'TaskDetailsScreen(task: task, profile: widget.profile)',
      'Прораб может добавлять задачи только на текущий день',
    ]);

    containsAllText('редактор задачи', taskDetailsEditorSource(), const [
      'final AppUserProfile profile;',
      'bool get canEdit => TaskEditPolicy.canEditTask',
      'bool get canEditDate =>',
      'TaskEditPolicy.canEditDate(widget.profile, widget.task)',
      'bool get canEditAxesWork =>',
      'TaskEditPolicy.canEditAxesWork(widget.profile, widget.task)',
      'bool get canEditAssignees =>',
      'TaskEditPolicy.canEditAssignees(widget.profile, widget.task)',
      'bool get canEditStatus =>',
      'TaskEditPolicy.canEditStatus(widget.profile, widget.task)',
      'bool get canDeleteTask =>',
      'TaskEditPolicy.canDeleteTask(widget.profile, widget.task)',
      'TaskEditPolicy.canDeletePhoto',
      'Future<void> deletePhoto(TaskPhotoData photo)',
      'TaskRepository.deleteTaskPhoto(photo)',
      "tooltip: 'Удалить фото'",
      'if (canDeleteTask)',
      'TaskEditPolicy.operationalToday',
    ]);

    containsAll('lib/screens/task_details_screen.dart', const [
      'editor.TaskDetailsScreen',
      'TaskProgressRepository.fetchContext',
      "'Что выполнили сегодня?'",
    ]);

    containsAll('lib/data/task_repository.dart', const [
      'Future<void> deleteTaskPhoto(TaskPhotoData photo)',
      'TaskPhotoRepository.deletePhoto(photo)',
    ]);
    containsAll('lib/data/task_photo_repository.dart', const [
      ".from('task_photos')",
      'removeStoragePaths(<String>[photo.storagePath])',
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

    containsAll(
      'supabase/migrations/20260718080500_developer_role_and_task_policy_schema.sql',
      const [
        'foreman_can_edit_past_tasks boolean not null default false',
        'edit_window_days integer',
        'foreman_can_edit_date boolean not null default true',
        'foreman_can_edit_axes_work boolean not null default true',
        'foreman_can_edit_assignees boolean not null default true',
        'foreman_can_edit_status boolean not null default true',
        'foreman_can_delete_task boolean not null default false',
      ],
    );

    containsAll(
      'supabase/migrations/20260718080600_developer_task_policy_rpcs.sql',
      const [
        'task_can_edit_for_user',
        "'foreman_can_edit_past_tasks'",
        "'edit_window_days'",
        'task_can_edit_assignees_for_user',
        'task_photo_can_delete_for_user',
        'task_can_delete_for_user',
      ],
    );
  });
}
