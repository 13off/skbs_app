import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/task_create_source.dart';
import 'support/task_details_source.dart';

String source(String path) => File(path).readAsStringSync();

void expectTextContains(
  String label,
  String text,
  Iterable<String> values,
) {
  for (final value in values) {
    expect(text, contains(value), reason: '$label должен содержать $value');
  }
}

void expectContains(String path, Iterable<String> values) {
  expectTextContains(path, source(path), values);
}

void main() {
  test('уведомления разделены по ролям и руководитель выбирает направления', () {
    expectContains(
      'supabase/migrations/20260718120000_role_notifications_and_task_photo_stages.sql',
      const [
        'notification_role_preferences',
        'source_role',
        'current_admin_notification_roles',
        'notification_visible_for_current_user',
        'set_my_notification_role_preferences',
        'populate_role_operational_reminders',
        "time '07:30'",
        "time '08:00'",
      ],
    );
    expectContains('lib/data/notification_repository.dart', const [
      'allNotificationRoles',
      'fetchSelectedNotificationRoles',
      'saveSelectedNotificationRoles',
      'source_role',
    ]);
    expectContains(
      'lib/screens/notification_control_center_screen.dart',
      const [
        'Роли и направления',
        'Типы событий',
        'Напоминания компании',
        'Сохранить все настройки',
      ],
    );
    expectContains('supabase/functions/dispatch-push-job/index.ts', const [
      'notification_role_preferences',
      'source_role',
      'adminPreferences',
      'sourceRole',
    ]);
  });

  test('фото До и После обязательны по умолчанию и настраиваются по объекту', () {
    expectContains(
      'supabase/migrations/20260718120000_role_notifications_and_task_photo_stages.sql',
      const [
        'photo_stage',
        'photo_requirements_enforced',
        'Добавьте хотя бы одно фото «До»',
        'Добавьте хотя бы одно фото «После»',
        'tasks_validate_photo_requirements',
      ],
    );
    expectContains(
      'supabase/migrations/20260718121000_harden_role_notifications_task_drafts.sql',
      const [
        'appstroy.suppress_draft_task_id',
        'alter column source_role drop default',
        'create or replace function public.app_notify_change()',
      ],
    );
    expectContains(
      'supabase/migrations/20260718122000_harden_task_delete_cascade.sql',
      const [
        'appstroy.deleting_task_id',
        'tasks_mark_delete',
        'prevent_required_task_photo_delete',
        'position(v_deleting_task_id in coalesce(new.body',
        'task_assignees',
        'task_photos',
      ],
    );
    expectContains(
      'supabase/migrations/20260718123000_preserve_task_delete_notification_company.sql',
      const [
        'appstroy.deleting_task_company_id',
        'assign_deleted_task_notification_company',
        'app_notifications_00_deleted_task_company',
      ],
    );
    expectContains(
      'supabase/migrations/20260718080500_developer_role_and_task_policy_schema.sql',
      const [
        'company_task_policies',
        'require_before_photo boolean not null default true',
        'min_before_photos integer not null default 1',
        'require_after_photo_on_complete boolean not null default true',
        'min_after_photos integer not null default 1',
      ],
    );
    expectContains(
      'supabase/migrations/20260718080700_task_policy_enforcement.sql',
      const [
        'get_effective_task_policy',
        "v_policy ->> 'require_before_photo'",
        "v_policy ->> 'require_after_photo_on_complete'",
        'task_can_create_for_user',
        'task_photo_can_delete_for_user',
      ],
    );
    expectContains('lib/data/task_repository.dart', const [
      "'is_draft': true",
      "'photo_requirements_enforced': policy.requireBeforePhoto",
      'policy.minBeforePhotos',
      "photoStage: 'before'",
      ".eq('is_draft', false)",
      "row['is_draft'] != true",
      'TaskPhotoRepository.uploadPhotos(',
    ]);
    expectContains('lib/data/task_photo_repository.dart', const [
      "'photo_stage': photoStage",
      "photoStage != 'before' && photoStage != 'after'",
      "bucketName = 'task-photos'",
    ]);
    expectTextContains('создание задачи', taskCreateSource(), const [
      'policy.requireBeforePhoto',
      'policy.minBeforePhotos',
      'Фото «До» — обязательно',
      'Фото «До» — по желанию',
    ]);
    expectTextContains(
      'редактор задачи',
      taskDetailsEditorSource(),
      const [
        "photoStage: 'before'",
        "photoStage: 'after'",
        'policy.requireAfterPhotoOnComplete',
        'policy.minAfterPhotos',
        "widget.task.status != 'Выполнено'",
      ],
    );
  });
}
