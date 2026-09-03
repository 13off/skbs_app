import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('master offline flow stays inside the existing app shell', () {
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final banner = File(
      'lib/widgets/offline_sync_banner.dart',
    ).readAsStringSync();

    expect(mainScreen, contains('OfflineSyncHost('));
    expect(mainScreen, contains('child: buildPlatform()'));
    expect(
      banner,
      contains('browserOffline || state.pendingCount > 0 || state.isSyncing'),
    );
    expect(banner, contains('_OfflineSyncIndicator('));
    expect(banner, contains('html.window.onOffline.listen'));
    expect(banner, contains('html.window.onOnline.listen'));
    expect(banner, contains('Нет связи с сервером'));
    expect(banner, contains('Отправляем данные'));
    expect(banner, contains('OfflineSyncService.flush()'));

    expect(banner, isNot(contains('_OfflinePendingBanner')));
    expect(banner, isNot(contains('Последняя синхронизация:')));
    expect(banner, isNot(contains('Хорошая сеть')));
    expect(banner, isNot(contains('Слабая сеть')));
  });

  test('timesheet saves through persistent offline queue', () {
    final actions = File(
      'lib/screens/timesheet/timesheet_actions.dart',
    ).readAsStringSync();
    final sync = File('lib/data/offline_sync_service.dart').readAsStringSync();

    expect(actions, contains('OfflineAttendanceRepository.saveTimesheet('));
    expect(sync, contains("kind == 'attendance.upsert'"));
    expect(sync, contains("case 'attendance.upsert':"));
    expect(sync, contains("'rows': rows.values.toList(growable: false)"));
  });

  test('existing task repository owns offline behavior for all task screens', () {
    final repository = File(
      'lib/data/task_repository.dart',
    ).readAsStringSync();
    final sync = File('lib/data/offline_sync_service.dart').readAsStringSync();

    expect(repository, contains("import 'offline_sync_service.dart';"));
    expect(repository, contains("kind: 'task.create'"));
    expect(repository, contains("kind: 'task.update'"));
    expect(repository, contains("kind: 'task.delete'"));
    expect(repository, contains("kind: 'task.assignees'"));
    expect(repository, contains("kind: 'task.photos.add'"));
    expect(sync, contains("case 'task.create':"));
    expect(sync, contains("case 'task.assignees':"));
    expect(sync, contains("case 'task.photos.add':"));
    expect(sync, contains('upsert: true'));
  });

  test('task form restores the last object policy when network drops', () {
    final loading = File(
      'lib/screens/task_create/task_create_loading.dart',
    ).readAsStringSync();
    final policy = File(
      'lib/features/developer/data/developer_policy_repository.dart',
    ).readAsStringSync();

    expect(loading, contains('OfflineEmployeeRepository.fetchEmployees('));
    expect(loading, contains('DeveloperPolicyRepository.ensurePolicy('));
    expect(loading, contains('forceRefresh: true'));
    expect(
      loading,
      contains('DeveloperPolicyRepository.policyForObjectSync('),
    );
    expect(policy, contains('OfflineSyncService.saveSnapshot('));
    expect(policy, contains('OfflineSyncService.readSnapshot('));
    expect(policy, contains('return entry?.policy ?? TaskPolicy.defaults;'));
  });
}
