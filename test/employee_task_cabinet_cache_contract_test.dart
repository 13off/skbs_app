import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('кабинет сотрудника объединяет одинаковые запросы и кешируется', () {
    final repository = File(
      'lib/features/employee/data/employee_task_cabinet_repository.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/data/app_cache_coordinator.dart',
    ).readAsStringSync();
    final home = File(
      'lib/features/employee/presentation/employee_home_screen.dart',
    ).readAsStringSync();
    final tasks = File(
      'lib/features/employee/presentation/employee_tasks_screen.dart',
    ).readAsStringSync();

    expect(repository, contains("static const Duration _cacheTtl"));
    expect(repository, contains('_requests[key]'));
    expect(repository, contains('if (running != null) return running;'));
    expect(repository, contains('bool forceRefresh = false'));
    expect(repository, contains('static void clearCache()'));
    expect(
      repository,
      contains("_cache[_cacheKey(result.profile.employeeId)]"),
    );

    expect(
      coordinator,
      contains('EmployeeTaskCabinetRepository.clearCache();'),
    );
    expect(home, contains('load(forceRefresh: true)'));
    expect(tasks, contains('load(forceRefresh: true)'));
  });
}
