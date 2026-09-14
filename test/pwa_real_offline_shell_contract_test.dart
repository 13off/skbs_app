import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA bootstrap installs the persistent AppStroy offline worker', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(bootstrap, contains('appstroy-offline-sw.js'));
    expect(bootstrap, contains('navigator.serviceWorker'));
    expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
    expect(bootstrap, contains("searchParams.get('v')"));
    expect(bootstrap, contains("workerUrl.searchParams.set('v', buildId)"));
    expect(bootstrap, contains("updateViaCache: 'none'"));
    expect(bootstrap, contains("addEventListener('controllerchange'"));
    expect(bootstrap, contains('window.location.reload()'));
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, isNot(contains('flutter_service_worker.js')));
  });

  test('offline worker owns navigation fallback and static shell cache', () {
    final worker = File('web/appstroy-offline-sw.js').readAsStringSync();

    expect(worker, contains("searchParams.get('v')"));
    expect(worker, contains(r'`appstroy-shell-${buildId}`'));
    expect(worker, contains(r'`appstroy-static-${buildId}`'));
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
