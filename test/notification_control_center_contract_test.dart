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
  test('руководитель управляет всеми внутренними настройками уведомлений', () {
    expectContains('lib/screens/settings_screen.dart', const [
      'Правила уведомлений компании',
      'NotificationControlCenterScreen',
    ]);
    expectContains(
      'lib/screens/notification_control_center_screen.dart',
      const [
        'Внутренний колокольчик',
        'Системные push',
        'Роли и направления',
        'Типы событий',
        'Напоминания компании',
        'Выключить все',
        'Сохранить все настройки',
      ],
    );
    expectContains('lib/data/notification_repository.dart', const [
      'NotificationControlSettings',
      'ReminderControlSetting',
      'fetchNotificationControlCenter',
      'saveNotificationControlCenter',
      'allNotificationEventGroups',
      'reminderDefinitions',
    ]);
  });

  test(
    'напоминания по умолчанию выключены и включаются только настройками',
    () {
      expectContains(
        'supabase/migrations/20260718150000_notification_control_center.sql',
        const [
          'company_reminder_settings',
          'enabled boolean not null default false',
          'get_my_notification_control_center',
          'set_my_notification_control_preferences',
          'set_company_reminder_settings',
          'and s.enabled = true',
          'populate_role_operational_reminders',
        ],
      );
    },
  );

  test('колокольчик и push учитывают роли, события и общие выключатели', () {
    expectContains(
      'supabase/migrations/20260718150000_notification_control_center.sql',
      const [
        'in_app_enabled',
        'push_enabled',
        'selected_event_groups',
        'notification_event_group',
        'current_admin_notification_in_app_enabled',
        'current_admin_notification_event_groups',
      ],
    );
    expectContains(
      'supabase/migrations/20260718153000_separate_bell_push_roles.sql',
      const [
        'selected_bell_roles',
        'selected_roles = array[]::text[]',
        'current_admin_notification_roles',
      ],
    );
    expectContains(
      'supabase/migrations/20260718153200_manager_push_routing.sql',
      const [
        'is_push_only',
        'ensure_manager_push_preferences',
        'route_manager_push_notifications',
        'p.push_enabled = true',
        'selected_event_groups',
      ],
    );
    expectContains(
      'supabase/migrations/20260718153300_hide_and_queue_manager_push.sql',
      const [
        'not is_push_only',
        'queue_push_notification_job',
        "m.role in ('admin','owner')",
      ],
    );
  });

  test('настройка устройства остаётся отдельной от правил компании', () {
    expectContains('lib/screens/push_notification_settings_screen.dart', const [
      'Push на устройстве',
      'Получать push на этом устройстве',
      'Общие правила задаются руководителем отдельно',
    ]);
  });
}
