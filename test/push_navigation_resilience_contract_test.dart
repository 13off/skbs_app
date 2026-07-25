import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push request is consumed only after navigator and auth are ready', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains('PushNotificationService.navigationRequest.value == null'),
    );
    expect(source, contains('auth.onAuthStateChange'));
    expect(
      source,
      contains(
        'final request = PushNotificationService.takeNavigationRequest();',
      ),
    );

    final readinessCheck = source.indexOf(
      'Supabase.instance.client.auth.currentUser == null',
    );
    final consumeRequest = source.indexOf(
      'final request = PushNotificationService.takeNavigationRequest();',
    );
    expect(readinessCheck, greaterThanOrEqualTo(0));
    expect(consumeRequest, greaterThan(readinessCheck));
  });

  test('startup screen does not expose raw infrastructure errors', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, isNot(contains('SelectableText(')));
    expect(source, isNot(contains('error.toString()')));
    expect(source, contains('Сервер временно недоступен'));
  });

  test('web push links stay inside the AppСтрой origin and scope', () {
    final worker = File('web/firebase-messaging-sw.js').readAsStringSync();

    expect(worker, contains('const safeNotificationTarget'));
    expect(worker, contains('new URL(value || appPublicLocation.href'));
    expect(worker, contains('target.origin === appPublicLocation.origin'));
    expect(worker, contains('target.pathname.startsWith(appScopePath)'));
    expect(
      worker,
      contains('return insideApp ? target.href : appPublicLocation.href'),
    );
  });
}
