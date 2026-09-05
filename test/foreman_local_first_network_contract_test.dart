import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('уведомления не запрашиваются автоматически при запуске или входе', () {
    final main = source('lib/screens/main_screen.dart');
    final users = source('lib/features/auth/data/user_repository.dart');

    expect(main, isNot(contains('Включить уведомления')));
    expect(main, isNot(contains('_bootstrapPushNotifications')));
    expect(users, isNot(contains('requestPermission: true')));
    expect(users, contains('PushNotificationService.syncForCurrentSession()'));
  });

  test('создание задачи всегда local-first независимо от navigator online', () {
    final form = source('lib/screens/add_task_screen.dart');
    final localCreate = source('lib/data/offline_task_create_service.dart');

    expect(form, contains('OfflineTaskCreateService.queueTask('));
    expect(form, isNot(contains('OfflineTaskCreateService.shouldQueueImmediately')));
    expect(form, isNot(contains('TaskRepository.addTaskWithDetails(')));
    expect(form, isNot(contains('TaskRepository.addTaskBatch(')));

    expect(localCreate, contains("kind: 'task.create'"));
    expect(localCreate, contains('OfflineSyncService.saveSnapshot('));
    expect(localCreate, contains('unawaited(OfflineSyncService.flush())'));
    expect(localCreate, isNot(contains('navigator.onLine')));
  });

  test('очередь повторяет отправку при всех доступных wake-up сигналах PWA', () {
    final host = source('lib/widgets/offline_sync_banner.dart');

    for (final fragment in const <String>[
      'html.window.onOnline.listen',
      'html.document.onVisibilityChange.listen',
      'html.window.onFocus.listen',
      'AppLifecycleState.resumed',
      'Timer.periodic(_retryInterval',
      'Duration(seconds: 20)',
    ]) {
      expect(host, contains(fragment));
    }
  });

  test('слабая LTE быстро переключает полевые чтения на локальные snapshots', () {
    final master = source('lib/data/offline_master_repository.dart');
    final policy = source(
      'lib/features/developer/data/developer_policy_repository.dart',
    );

    expect(master, contains('_fieldNetworkDeadline = Duration(seconds: 3)'));
    expect(master, contains('.timeout(_fieldNetworkDeadline)'));
    expect(policy, contains('_fieldNetworkDeadline = Duration(seconds: 3)'));
    expect(policy, contains('.timeout(_fieldNetworkDeadline)'));
  });
}
