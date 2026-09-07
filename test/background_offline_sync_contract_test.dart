import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native offline queue is scheduled for background delivery', () {
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
    expect(service, contains('registerProcessingTask'));
    expect(service, contains('OfflineSyncService.flush()'));
    expect(service, isNot(contains("from('tasks')")));
    expect(service, isNot(contains("storage.from('task-photos')")));

    expect(host, contains('OfflineSyncService.state.addListener'));
    expect(host, contains('BackgroundOfflineSyncService.schedule'));
    expect(host, contains('OfflineSyncService.state.removeListener'));
  });

  test('ios registers background processing task and plugin registrant', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(info, contains('<string>processing</string>'));
    expect(info, contains('BGTaskSchedulerPermittedIdentifiers'));
    expect(info, contains('com.example.skbsApp.offlineSync'));
    expect(delegate, contains('import workmanager_apple'));
    expect(delegate, contains('WorkmanagerPlugin.registerLaunchHandlers()'));
    expect(delegate, contains('WorkmanagerPlugin.setPluginRegistrantCallback'));
    expect(delegate, contains('WorkmanagerPlugin.registerBGProcessingTask'));
    expect(delegate, contains('com.example.skbsApp.offlineSync'));
    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
    expect(project, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;'));
  });
}
