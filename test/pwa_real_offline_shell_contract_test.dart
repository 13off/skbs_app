import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA bootstrap uses AppStroy persistent offline worker', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(bootstrap, contains("appstroy-offline-sw.js"));
    expect(bootstrap, contains('navigator.serviceWorker'));
    expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, isNot(contains('flutter_service_worker.js')));
  });

  test('offline worker owns navigation fallback and static shell cache', () {
    final worker = File('web/appstroy-offline-sw.js').readAsStringSync();

    expect(worker, contains("const SHELL_CACHE = 'appstroy-shell-v1'"));
    expect(worker, contains("self.addEventListener('install'"));
    expect(worker, contains("self.addEventListener('activate'"));
    expect(worker, contains("self.addEventListener('fetch'"));
    expect(worker, contains('self.clients.claim()'));
    expect(worker, contains("request.mode === 'navigate'"));
    expect(worker, contains("atScope('index.html')"));
    expect(worker, contains('ignoreSearch: true'));
    expect(worker, contains("'main.dart.js'"));
    expect(worker, contains("'canvaskit/canvaskit.wasm'"));
  });
}
