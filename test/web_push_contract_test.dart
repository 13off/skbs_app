import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void containsAll(String path, Iterable<String> fragments) {
  final contents = source(path);
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный Web Push элемент "$fragment" отсутствует в $path',
    );
  }
}

void main() {
  test('iPhone PWA использует стандартный Web Push без Firebase Web', () {
    containsAll('lib/services/push_notification_service.dart', const [
      "import 'web_push_bridge.dart';",
      'WebPushBridge.subscribe',
      "'manage-web-push-device'",
      'На iPhone добавьте AppСтрой на экран «Домой»',
    ]);
    containsAll('lib/services/web_push_bridge_web.dart', const [
      "'appstroy-push-sw.js'",
      "'push-scope/'",
      "'appstroy-push-config.json'",
      "'applicationServerKey'",
      "'getSubscription'",
      "'subscribe'",
      "'unsubscribe'",
    ]);
    containsAll('web/appstroy-push-sw.js', const [
      "self.addEventListener('push'",
      "self.addEventListener('notificationclick'",
      'showNotification',
      'clients.openWindow',
    ]);
    containsAll('web/appstroy-push-config.json', const [
      'public_key',
    ]);
    containsAll(
      'supabase/migrations/20260718093000_add_standard_web_push.sql',
      const [
        'create table if not exists public.web_push_subscriptions',
        'appstroy_web_push_vapid_private_key',
        'revoke all on table public.web_push_subscriptions',
      ],
    );
    containsAll('supabase/functions/manage-web-push-device/index.ts', const [
      'userClient.auth.getUser()',
      'web_push_subscriptions',
      'active_company_id',
      'company_memberships',
    ]);
    containsAll('supabase/functions/dispatch-push-job/index.ts', const [
      'npm:web-push',
      'web_push_subscriptions',
      'get_push_secret',
      'sendToWebSubscription',
      'vapidDetails',
      'disabled_web_push_count',
    ]);
    containsAll('lib/screens/push_notification_settings_screen.dart', const [
      'На iPhone AppСтрой должен быть добавлен на экран «Домой»',
      'Системная доставка доступна',
    ]);
  });
  test('web push registration is serialized and idempotent', () {
    final service = File(
      'lib/services/push_notification_service.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/manage-web-push-device/index.ts',
    ).readAsStringSync();

    expect(service, contains('_webSyncInFlight'));
    expect(service, contains('_webRegistrationInFlight'));
    expect(service, contains('_syncWebPushSerialized'));
    expect(edge, contains('.upsert({'));
    expect(edge, contains('{ onConflict: "endpoint" }'));
    expect(edge, isNot(contains('endpointDeleteError')));
  });

}
