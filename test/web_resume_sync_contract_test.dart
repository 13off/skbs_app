import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('web resume does not trigger a full data refresh', () {
    final sync = source('lib/data/app_data_sync.dart');
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expect(shell, contains('AppDataSync.refreshAll()'));
    expect(sync, contains("import 'package:flutter/foundation.dart';"));
    expect(sync, contains('static void refreshAll()'));
    expect(sync, contains('if (kIsWeb) return;'));
    expect(sync, contains("_queueFullRefresh(source: 'resume')"));
  });

  test('real realtime reconnect still refreshes every platform', () {
    final sync = source('lib/data/app_data_sync.dart');

    expect(sync, contains('if (_hasSubscribedOnce) _refreshAfterReconnect()'));
    expect(sync, contains('static void _refreshAfterReconnect()'));
    expect(sync, contains("_queueFullRefresh(source: 'reconnect')"));
    expect(sync, contains('AppDataDomain.attendance'));
    expect(sync, contains('AppDataDomain.employees'));
    expect(sync, contains('AppDataDomain.objects'));
  });
}
