import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MAX-мост сохраняет быстрый опрос без лишних служебных запросов', () {
    final bridge = File(
      'supabase/functions/max-recruitment-bridge/index.ts',
    ).readAsStringSync();
    final appStroy = File(
      'services/max-recruiting-bot/src/appstroy.js',
    ).readAsStringSync();
    final bot = File(
      'services/max-recruiting-bot/src/index.js',
    ).readAsStringSync();

    expect(bridge, contains('const EXPECTED_SECRET_SHA256'));
    expect(bridge, contains('crypto.subtle.digest("SHA-256"'));
    expect(bridge, contains('function constantTimeEqual'));
    expect(bridge, isNot(contains('get_recruitment_secret')));
    expect(
      bridge,
      contains('url.searchParams.get("recover_stale") === "1"'),
    );
    expect(appStroy, contains('this.lastOutboundRecoveryAt = 0'));
    expect(appStroy, contains("recover_stale: recoverStale ? '1' : ''"));
    expect(appStroy, contains('>= 60_000'));
    expect(bot, contains('}, 5_000).unref();'));
  });
}
