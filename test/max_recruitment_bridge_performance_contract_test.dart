import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MAX-мост сохраняет быстрый опрос без лишних служебных запросов', () {
    final bridge = File(
      'supabase/functions/max-recruitment-bridge/index.ts',
    ).readAsStringSync();
    final bot = File(
      'services/max-recruiting-bot/src/index.js',
    ).readAsStringSync();

    expect(bridge, contains('const SECRET_CACHE_TTL_MS = 60_000'));
    expect(
      bridge,
      contains('const STALE_OUTBOUND_SWEEP_INTERVAL_MS = 60_000'),
    );
    expect(bridge, contains('let expectedSecretRequest'));
    expect(bridge, contains('let staleOutboundSweepRequest'));
    expect(bridge, contains('await recoverStaleOutboundMessages();'));
    expect(bot, contains('}, 5_000).unref();'));
  });
}
