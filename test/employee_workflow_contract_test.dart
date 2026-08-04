import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('упрощённые вкладки используют единый серверный выбор сотрудника', () {
    final wrapper = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final workActions = File(
      'lib/features/employee/data/employee_work_action_repository.dart',
    ).readAsStringSync();

    expect(wrapper, contains('EmployeeHomeScreen'));
    expect(wrapper, contains('EmployeeTasksScreen'));
    expect(wrapper, contains('ProfileScreen(profile: contentProfile)'));
    expect(profile, contains('EmployeeWorkTaskHistoryScreen'));
    expect(wrapper, contains("actualRole: 'employee'"));
    expect(wrapper, isNot(contains('Предпросмотр:')));
    expect(workActions, contains('resolveSelection()'));
    expect(workActions, contains("'resolve_selection'"));
  });

  test(
    'сотрудник начинает смену и добавляет фото через защищённую функцию',
    () {
      final repository = File(
        'lib/features/employee/data/employee_work_action_repository.dart',
      ).readAsStringSync();
      final screen = File(
        'lib/features/employee/presentation/employee_work_cabinet_screen.dart',
      ).readAsStringSync();
      final edge = File(
        'supabase/functions/employee-work-actions/index.ts',
      ).readAsStringSync();

      expect(repository, contains("'start_shift'"));
      expect(repository, contains("'finish_shift'"));
      expect(repository, contains("'upload_task_photo'"));
      expect(screen, contains("label: 'Начать смену'"));
      expect(screen, contains("'Завершить рабочий день'"));
      expect(screen, contains('TaskRepository.pickPhotoFiles()'));
      expect(screen, contains("addPhotos('before')"));
      expect(screen, contains("addPhotos('after')"));
      expect(edge, contains('assignedTask'));
      expect(edge, contains('status: "В работе"'));
      expect(edge, contains('.from("task-photos")'));
      expect(edge, contains('.from("task_photos")'));
    },
  );
}
