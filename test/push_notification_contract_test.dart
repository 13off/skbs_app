import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void containsAll(String path, Iterable<String> fragments) {
  final contents = source(path);
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный push-элемент "$fragment" отсутствует в $path',
    );
  }
}

void main() {
  test('push работает поверх внутреннего колокольчика и защищает компании', () {
    containsAll('pubspec.yaml', const [
      'firebase_core:',
      'firebase_messaging:',
    ]);
    containsAll('lib/main.dart', const [
      'PushNotificationService.initialize()',
      'NotificationsScreen(',
      'startupError',
    ]);
    containsAll('lib/services/push_notification_service.dart', const [
      'FIREBASE_VAPID_KEY',
      'firebaseMessagingBackgroundHandler',
      'onTokenRefresh',
      "serviceWorkerScriptPath: kIsWeb",
      "'manage-push-device'",
      "'dispatch-push-notification'",
      "'action': 'unregister'",
      'Push идёт поверх внутреннего колокольчика',
    ]);
    containsAll('lib/data/notification_repository.dart', const [
      "'app_notifications'",
      "'app_notification_reads'",
      "'app_notification_clears'",
      ".select('id')",
      'PushNotificationService.dispatchNotification(notificationId)',
      'Уведомления не должны ломать основное действие',
    ]);
    containsAll('lib/screens/profile_screen.dart', const [
      "'Push-уведомления'",
      'PushNotificationSettingsScreen',
      "'Компания и пользователи'",
      "'Архив и удаление'",
      "'Документы'",
    ]);
    containsAll('lib/screens/push_notification_settings_screen.dart', const [
      "'Получать push на этом устройстве'",
      "'Разрешить и подключить'",
      'Внутренний колокольчик продолжает работать независимо.',
    ]);
    containsAll(
      'supabase/migrations/20260713123000_add_push_notification_delivery.sql',
      const [
        'create table if not exists public.push_device_tokens',
        'user_id uuid not null references auth.users',
        'company_id uuid not null references public.companies',
        'enable row level security',
        'push_notification_deliveries',
        'revoke all on table public.push_device_tokens from anon, authenticated',
      ],
    );
    containsAll(
      'supabase/migrations/20260713130000_move_push_device_management_to_edge.sql',
      const [
        'drop function if exists public.register_current_push_device',
        'drop function if exists public.set_current_push_device_enabled',
        'drop function if exists public.unregister_current_push_device',
      ],
    );
    containsAll('supabase/functions/manage-push-device/index.ts', const [
      'userClient.auth.getUser()',
      '.select("active_company_id, is_active")',
      '.eq("company_id", companyId)',
      '.eq("user_id", userData.user.id)',
      'push_device_tokens',
      'SUPABASE_SERVICE_ROLE_KEY',
    ]);
    containsAll('supabase/functions/dispatch-push-notification/index.ts', const [
      'notification.actor_user_id !== userData.user.id',
      '.eq("company_id", notification.company_id)',
      'foremanAllowedEntityTypes',
      '.neq("user_id", userData.user.id)',
      'FIREBASE_SERVICE_ACCOUNT_JSON',
      'UNREGISTERED',
      'https://fcm.googleapis.com/v1/projects/',
    ]);
    containsAll(
      'supabase/migrations/20260717210809_add_automatic_push_jobs_and_reminders.sql',
      const [
        'create table if not exists public.push_notification_jobs',
        'app_notifications_queue_push',
        'dispatch-push-job',
        "array['admin','foreman','lawyer','accountant','hr']",
        'private.process_due_scheduled_reminders()',
        'appstroy-process-due-reminders',
        'candidate_ready_tomorrow',
        'candidate_ready_today',
        'appstroy-retry-failed-push-jobs',
      ],
    );
    containsAll('supabase/functions/dispatch-push-job/index.ts', const [
      'push_notification_jobs',
      'dispatch_token',
      'FIREBASE_SERVICE_ACCOUNT_JSON',
      'https://fcm.googleapis.com/v1/projects/',
      'no_enabled_device_tokens',
      'UNREGISTERED',
    ]);
    containsAll('docs/firebase-push-setup.md', const [
      'FIREBASE_SERVICE_ACCOUNT_JSON',
      'Профиль → Push-уведомления',
      'каждые 5 минут',
    ]);
    containsAll('web/firebase-messaging-sw.js', const [
      'firebase-messaging-compat.js',
      'onBackgroundMessage',
      'notificationclick',
      '__FIREBASE_WEB_APP_ID__',
    ]);
    containsAll('android/app/src/main/AndroidManifest.xml', const [
      'android.permission.POST_NOTIFICATIONS',
      'com.google.firebase.messaging.default_notification_icon',
    ]);
    containsAll('ios/Runner/Info.plist', const [
      'UIBackgroundModes',
      'remote-notification',
    ]);
    containsAll('ios/Runner/Runner.entitlements', const [
      'aps-environment',
    ]);
    containsAll('docs/FUNCTIONAL_BASELINE.md', const [
      'Push работает поверх внутренней истории и не заменяет её.',
      'Ошибка Firebase, APNs, Web Push или Edge Function не должна ломать',
      'Токен устройства связан с `user_id`, `company_id`',
    ]);
  });
}
