import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void containsAll(String path, Iterable<String> fragments) {
  final contents = source(path);
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный offline-first элемент "$fragment" отсутствует в $path',
    );
  }
}

void main() {
  test('offline host сохраняет очередь и отправляет её после возврата связи', () {
    containsAll('lib/widgets/offline_sync_banner.dart', const [
      'OfflineSyncService.configure(',
      'OfflineSyncService.flush()',
      '_syncAfterConnectivitySignal()',
      'OfflineSyncService.pendingCount > 0',
      'Timer.periodic(_retryInterval',
      'AppLifecycleState.resumed',
      "'Ожидает отправки: ",
    ]);

    containsAll('lib/data/offline_sync_service.dart', const [
      "static const String _prefix = 'appstroy_offline_v1'",
      "case 'attendance.upsert':",
      "case 'task.create':",
      "case 'task.update':",
      "case 'task.delete':",
      "case 'task.photos.add':",
      'if (isNetworkFailure(error)) break;',
      'Пользовательские данные не удаляются',
    ]);
  });

  test('профиль и рабочие данные мастера доступны из локальных снимков', () {
    containsAll(
      'lib/features/auth/presentation/offline_first_auth_gate.dart',
      const [
        'OfflineProfileStore.read(user.id)',
        'MainScreen(profile: profile)',
        'При полном отсутствии сети сохранённый профиль остаётся рабочим',
      ],
    );

    containsAll('lib/data/offline_master_repository.dart', const [
      'class OfflineEmployeeRepository',
      'class OfflineObjectRepository',
      'class OfflineAttendanceRepository',
      'OfflineSyncService.saveSnapshot(',
      "kind: 'attendance.upsert'",
      'OfflineSyncService.hasPending(',
      'fetchResponsibilityForDate(',
    ]);
  });

  test('мобильный и ПК табель работают через offline-first слой', () {
    containsAll('lib/screens/timesheet/timesheet_loading.dart', const [
      'OfflineEmployeeRepository.fetchEmployees(',
      'OfflineAttendanceRepository.fetchShiftValuesForDate(',
      'OfflineAttendanceRepository.fetchResponsibilityForDate(',
      'TimesheetGroupRepository.fetchGroups(',
    ]);
    containsAll('lib/screens/timesheet/timesheet_actions.dart', const [
      'OfflineAttendanceRepository.saveTimesheet(',
      'OfflineAttendanceRepository.fetchResponsibilityForDate(',
    ]);
    containsAll('lib/screens/desktop_timesheet_screen.dart', const [
      'OfflineEmployeeRepository.fetchEmployees(',
      'OfflineAttendanceRepository.fetchShiftValuesForDate(',
      'OfflineAttendanceRepository.saveTimesheet(',
      'OfflineAttendanceRepository.fetchResponsibilityForDate(',
      'TimesheetGroupRepository.fetchGroups(',
    ]);
    containsAll(
      'lib/features/timesheet/data/timesheet_group_repository.dart',
      const [
        'OfflineSyncService.saveSnapshot(',
        'OfflineSyncService.readSnapshot(',
        'OfflineSyncService.isNetworkFailure(error)',
      ],
    );
  });

  test('рабочая смена и задачи мастера не зависят от постоянной сети', () {
    containsAll('lib/features/foreman/presentation/foreman_desktop_home_screen.dart', const [
      'OfflineEmployeeRepository.fetchEmployees(',
      'OfflineAttendanceRepository.fetchShiftValuesForDate(',
      'TaskRepository.fetchTasksForDate(',
      'ForemanWorkspaceRepository.fetchOverdueTasks(',
      'ForemanWorkspaceRepository.fetchTaskMeta(',
    ]);
    containsAll('lib/features/foreman/data/foreman_workspace_repository.dart', const [
      'OfflineSyncService.saveSnapshot(',
      'OfflineSyncService.readSnapshot(',
      'OfflineSyncService.isNetworkFailure(error)',
    ]);
    containsAll('lib/data/task_repository.dart', const [
      '_queueTaskCreate(',
      "kind: 'task.create'",
      "kind: 'task.update'",
      "kind: 'task.delete'",
      "kind: 'task.assignees'",
      "kind: 'task.photos.add'",
      '_mergePendingTaskOverlay(',
      'fetchTaskAssignees(',
      'fetchTaskPhotos(',
    ]);
    containsAll('lib/screens/add_task_screen.dart', const [
      "import '../data/offline_master_repository.dart';",
      'OfflineEmployeeRepository',
    ]);
  });

  test('главная мастера не блокируется админскими финансами и этапы кешируются', () {
    final homeLoading = source('lib/screens/home/home_loading.dart');
    expect(homeLoading, contains('widget.profile.isAdmin'));
    expect(homeLoading, contains('FinanceSummaryData.empty'));
    expect(homeLoading, contains('OfflineEmployeeRepository.fetchEmployees('));
    expect(
      homeLoading,
      contains('OfflineAttendanceRepository.fetchWorkedEmployeeIds('),
    );

    containsAll('lib/features/milestones/data/milestone_repository.dart', const [
      "return 'milestones::",
      '_saveMilestoneSnapshot(',
      '_readMilestoneSnapshot(',
      'OfflineSyncService.isNetworkFailure(error)',
      'if (cached == null) rethrow;',
    ]);
  });
}
