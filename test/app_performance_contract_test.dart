import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Performance contract: keep navigation/cache optimizations from regressing.
// Validated after removing formatting-only diff noise and route import fixes.
void main() {
  test('persistent tabs are warmed in scheduler idle time', () {
    final source = File(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    ).readAsStringSync();
    expect(source, contains('Priority.idle'));
    expect(source, contains('_prewarmNextTab'));
    expect(source, contains('IndexedStack'));
    expect(source, contains('TickerMode'));
  });

  test('explicit pushes use the lightweight app route', () {
    final route = File('lib/navigation/app_page_route.dart').readAsStringSync();
    expect(route, contains('Duration(milliseconds: 190)'));
    expect(route, contains('RepaintBoundary(child: child)'));

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('navigation/app_page_route.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('CupertinoPageRoute') ||
          source.contains('MaterialPageRoute')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: 'Heavy routes remain: $offenders');
  });

  test('timesheet group reads are cached and coalesced', () {
    final source = File(
      'lib/features/timesheet/data/timesheet_group_repository.dart',
    ).readAsStringSync();
    expect(source, contains('_cacheTtl'));
    expect(source, contains('_inFlight'));
    expect(source, contains('forceRefresh = false'));
    expect(source, contains('clearCache()'));
  });

  test('startup restores independent local state in parallel', () {
    final source = File('lib/screens/main_screen.dart').readAsStringSync();
    expect(source, contains('await Future.wait<void>'));
    expect(source, contains('NavigationSession.configure'));
    expect(source, contains('RolePreviewController.restore'));
  });

  test('mobile PWA avoids always-on glass blur in persistent chrome', () {
    final page = File('lib/widgets/app_page.dart').readAsStringSync();
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();
    expect(page, contains('blur: !kIsWeb || isDesktop'));
    expect(navigation, contains('blur: !kIsWeb || isDesktop'));
  });

  test('realtime refreshes reuse unaffected caches', () {
    final home = File('lib/screens/home/home_loading.dart').readAsStringSync();
    final tasks = File(
      'lib/screens/desktop_tasks_screen.dart',
    ).readAsStringSync();
    final payments = File(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    ).readAsStringSync();
    expect(home, contains('dashboardFuture = loadDashboardData();'));
    expect(tasks, contains('loadTasks(silent: true);'));
    expect(payments, contains('loadPaymentsData();'));
  });

  test('desktop timesheet group lookup is indexed', () {
    final source = File(
      'lib/screens/desktop_timesheet_screen.dart',
    ).readAsStringSync();
    expect(source, contains('groupByEmployeeId'));
    expect(source, contains('groupIndexById'));
    expect(source, contains('return groupByEmployeeId[employeeId]'));
  });

  test('recruitment search rebuilds are debounced', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();
    expect(source, contains('Timer? searchDebounce'));
    expect(source, contains('Duration(milliseconds: 90)'));
  });
}
