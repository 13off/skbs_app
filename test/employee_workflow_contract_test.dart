import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('все вкладки предпросмотра используют единый выбор сотрудника', () {
    final wrapper = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final team = File(
      'lib/features/employee/presentation/employee_team_tab_screen.dart',
    ).readAsStringSync();

    expect(wrapper, contains('EmployeeWorkHomeScreen'));
    expect(wrapper, contains('EmployeeWorkTasksScreen'));
    expect(wrapper, contains('profile.isRolePreview ? null'));
    expect(team, contains('EmployeeWorkActionRepository.resolveSelection()'));
    expect(team, isNot(contains('_resolvePreviewSeed')));
    expect(team, isNot(contains('EmployeeRepository.fetchEmployees')));
  });

  test('сотрудник может начать задачу и добавить фото через защищённую функцию', () {
    final repository = File(
      'lib/features/employee/data/employee_work_action_repository.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/employee/presentation/employee_work_cabinet_screen.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/employee-work-actions/index.ts',
    ).readAsStringSync();

    expect(repository, contains("'start_task'"));
    expect(repository, contains("'upload_task_photo'"));
    expect(screen, contains("label: 'Начать работу'"));
    expect(screen, contains('TaskRepository.pickPhotoFiles()'));
    expect(screen, contains("addPhotos('before')"));
    expect(screen, contains("addPhotos('after')"));
    expect(edge, contains('assertAssignedTask'));
    expect(edge, contains('status: "В работе"'));
    expect(edge, contains('.from("task-photos")'));
    expect(edge, contains('.from("task_photos")'));
  });
}
