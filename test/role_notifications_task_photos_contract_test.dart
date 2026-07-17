import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void expectContains(String path, Iterable<String> values) {
  final text = source(path);
  for (final value in values) {
    expect(text, contains(value), reason: '$path должен содержать $value');
  }
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
    expectContains('lib/screens/push_notification_settings_screen.dart', const [
      'Какие роли учитывать',
      'Руководителю по умолчанию доступны все направления',
      'Сохранить роли',
    ]);
    expectContains('supabase/functions/dispatch-push-job/index.ts', const [
      'notification_role_preferences',
      'source_role',
      'adminPreferences',
      'sourceRole',
    ]);
  });

  test('новая задача требует фото До, а выполнение требует фото После', () {
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
    expectContains('lib/data/task_repository.dart', const [
      "'is_draft': true",
      "'photo_requirements_enforced': true",
      "photoStage: 'before'",
      "'photo_stage': photoStage",
    ]);
    expectContains('lib/screens/add_task_screen.dart', const [
      'Фото «До» — обязательно',
      'Добавьте хотя бы одно фото «До»',
    ]);
    expectContains('lib/screens/task_details_legacy_screen.dart', const [
      "photoStage: 'before'",
      "photoStage: 'after'",
      'Без фото «После» задачу нельзя выполнить',
      'Сначала добавьте хотя бы одно фото «После»',
    ]);
  });
}
