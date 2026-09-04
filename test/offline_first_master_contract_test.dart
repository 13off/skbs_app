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
    expect(banner, contains('final showIndicator ='));
    expect(
      banner,
      contains('!_isOnline || state.isSyncing || state.pendingCount > 0'),
    );
    expect(banner, contains("? 'Нет сети'"));
    expect(banner, contains('Ожидает отправки:'));
    expect(banner, contains('Сервер ещё не подтвердил эти изменения'));
    expect(banner, contains('Последняя успешная связь с сервером:'));
    expect(banner, contains('OfflineSyncService.flush()'));
    expect(banner, contains('if (showIndicator)'));

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

  test('task form keeps old policy and employee flow when network drops', () {
    final loading = File(
      'lib/screens/task_create/task_create_loading.dart',
    ).readAsStringSync();
    final policy = File(
      'lib/features/developer/data/developer_policy_repository.dart',
    ).readAsStringSync();

    expect(loading, contains('OfflineEmployeeRepository.fetchEmployees('));
    expect(
      loading,
      contains('DeveloperPolicyRepository.policyForObjectSync('),
    );
    expect(policy, contains('return entry?.policy ?? TaskPolicy.defaults;'));
  });
}
