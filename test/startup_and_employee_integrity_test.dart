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

  test('смена пользователя или компании очищает ролевые кеши', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(main, contains('identityChanged'));
    expect(main, contains('companyChanged'));
    expect(main, contains('clearRepositoryCaches()'));
    expect(main, contains('AttendanceRepository.clearCache()'));
    expect(main, contains('EmployeeRepository.clearCache()'));
    expect(main, contains('ObjectRepository.clearCache()'));
    expect(main, contains('PaymentRepository.clearCache()'));
    expect(main, contains('TaskRepository.clearTaskListCache()'));
    expect(main, contains('DeveloperPolicyRepository.clearCache()'));
    expect(main, contains('ManagerReportsRepository.clearCache()'));
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
}
