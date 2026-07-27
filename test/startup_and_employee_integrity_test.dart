import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('стартовый прогрев не дублирует задачи и табель', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(main, isNot(contains('AttendanceRepository.fetchShiftValuesForDate')));
    expect(main, isNot(contains('TaskRepository.fetchTasksForDate')));
    expect(main, contains('EmployeeRepository.fetchEmployees'));
    expect(main, contains('ObjectRepository.fetchObjects'));
  });

  test('новая сессия очищает кеши до навигации и прогрева', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final initStateStart = main.indexOf('void initState()');
    final clearPosition = main.indexOf(
      'AppCacheCoordinator.clearAll();',
      initStateStart,
    );
    final restorePosition = main.indexOf(
      'navigationRestoreFuture = restoreNavigation();',
      initStateStart,
    );
    final warmupPosition = main.indexOf(
      'unawaited(warmUpApplication());',
      initStateStart,
    );

    expect(initStateStart, greaterThanOrEqualTo(0));
    expect(clearPosition, greaterThan(initStateStart));
    expect(restorePosition, greaterThan(clearPosition));
    expect(warmupPosition, greaterThan(restorePosition));
  });

  test('смена пользователя или компании очищает ролевые кеши', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final coordinator = File(
      'lib/data/app_cache_coordinator.dart',
    ).readAsStringSync();

    expect(main, contains('identityChanged'));
    expect(main, contains('companyChanged'));
    expect(main, contains('AppCacheCoordinator.clearAll()'));
    expect(coordinator, contains('AttendanceRepository.clearCache()'));
    expect(coordinator, contains('EmployeeRepository.clearCache()'));
    expect(coordinator, contains('ObjectRepository.clearCache()'));
    expect(coordinator, contains('PaymentRepository.clearCache()'));
    expect(coordinator, contains('TaskRepository.clearTaskListCache()'));
    expect(coordinator, contains('DeveloperPolicyRepository.clearCache()'));
    expect(coordinator, contains('ManagerReportsRepository.clearCache()'));
  });

  test('один человек не получает две активные карточки на одном объекте', () {
    final migration = File(
      'supabase/migrations/20260720160000_employee_assignment_integrity.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('employees_one_active_assignment_per_object_key'),
    );
    expect(
      migration,
      contains('where is_active and archived_at is null'),
    );
    expect(migration, contains('sync_employee_personal_fields'));
    expect(migration, contains('sibling.person_id = new.person_id'));
    expect(migration, contains('from public, anon, authenticated'));
  });

  test('служебный обработчик напоминаний недоступен клиенту', () {
    final migration = File(
      'supabase/migrations/20260720173000_close_private_reminder_executor.sql',
    ).readAsStringSync();

    expect(migration, contains('populate_developer_custom_reminders'));
    expect(migration, contains('from public, anon, authenticated'));
  });
}
