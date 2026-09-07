import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native offline queue keeps one authoritative flush implementation', () {
    final service = File(
      'lib/services/background_offline_sync_service.dart',
    ).readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final host = File(
      'lib/widgets/offline_sync_banner.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('workmanager: 0.10.9'));
    expect(mainSource, contains('BackgroundOfflineSyncService.initialize()'));
    expect(service, contains('NetworkType.connected'));
    expect(service, contains('registerOneOffTask'));
    expect(service, contains('BackoffPolicy.linear'));
    expect(service, contains('OfflineSyncService.flush()'));
    expect(service, contains('auth.refreshSession()'));
    expect(service, isNot(contains("from('tasks')")));
    expect(service, isNot(contains("storage.from('task-photos')")));

    expect(host, contains('OfflineSyncService.state.addListener'));
    expect(host, contains('BackgroundOfflineSyncService.schedule'));
    expect(host, contains('OfflineSyncService.state.removeListener'));
  });

  test('ios waits for network through a persistent background URLSession', () {
    final service = File(
      'lib/services/background_offline_sync_service.dart',
    ).readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(service, contains("invokeMethod<bool>(\n          'scheduleWake'"));
    expect(service, isNot(contains('registerProcessingTask')));
    expect(service, contains('ios-background-transfer-scheduled'));

    expect(mainSource, contains("@pragma('vm:entry-point')"));
    expect(mainSource, contains('iosBackgroundNetworkWakeMain'));
    expect(mainSource, contains('runScheduledFlush()'));
    expect(mainSource, contains('reportIosHeadlessFlushResult'));

    expect(scene, contains('URLSessionConfiguration.background'));
    expect(scene, contains('sessionSendsLaunchEvents = true'));
    expect(scene, contains('isDiscretionary = false'));
    expect(scene, contains('downloadTask(with: request)'));
    expect(scene, contains('background-network-probe-scheduled'));
    expect(scene, contains('FlutterEngine('));
    expect(scene, contains('allowHeadlessExecution: true'));
    expect(scene, contains('iosBackgroundNetworkWakeMain'));
    expect(scene, contains('BGProcessingTaskRequest'));
    expect(scene, contains('requiresNetworkConnectivity = true'));

    expect(delegate, isNot(contains('import workmanager_apple')));
    expect(delegate, contains('OfflineBackgroundSyncWakeCoordinator.shared.prepare()'));
    expect(delegate, contains('AppStroyOfflineBackgroundSync'));
    expect(delegate, contains('handleEventsForBackgroundURLSession'));

    expect(info, contains('<string>processing</string>'));
    expect(info, contains('BGTaskSchedulerPermittedIdentifiers'));
    expect(
      info,
      contains(r'<string>$(PRODUCT_BUNDLE_IDENTIFIER).offlineSync</string>'),
    );
    expect(info, isNot(contains('com.example.skbsApp.offlineSync')));

    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
    expect(project, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'));
  });
}
