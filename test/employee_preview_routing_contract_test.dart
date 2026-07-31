import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const controllerPath =
      'lib/features/role_preview/role_preview_controller.dart';
  const navigationPath = 'lib/navigation/navigation_session.dart';
  const roleScreenPath =
      'lib/features/role_preview/role_preview_screen.dart';
  const mainPath = 'lib/screens/main_screen.dart';
  const platformPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const cabinetFunctionPath =
      'supabase/functions/employee-task-cabinet/index.ts';

  test('режим сотрудника хранит конкретную карточку', () {
    final controller = File(controllerPath).readAsStringSync();
    final navigation = File(navigationPath).readAsStringSync();

    expect(controller, contains('final String employeeId;'));
    expect(controller, contains('required String employeeId'));
    expect(controller, contains('savedEmployeeId.isNotEmpty'));
    expect(navigation, contains("preview.employee_id"));
    expect(navigation, contains("preview.employee_name"));
  });

  test('руководитель выбирает сотрудника перед открытием кабинета', () {
    final roleScreen = File(roleScreenPath).readAsStringSync();
    final main = File(mainPath).readAsStringSync();
    final platform = File(platformPath).readAsStringSync();

    expect(roleScreen, contains('EmployeeRepository.fetchEmployees()'));
    expect(roleScreen, contains('Выберите сотрудника'));
    expect(roleScreen, contains('RolePreviewController.showEmployee('));
    expect(main, contains('previewEmployeeId: preview.employeeId'));
    expect(platform, contains('widget.initialEmployeeId.trim()'));
  });

  test('сервер не подставляет последнего исполнителя задачи', () {
    final function = File(cabinetFunctionPath).readAsStringSync();

    expect(
      function,
      contains('Выберите сотрудника для режима просмотра'),
    );
    expect(function, isNot(contains('recentEmployeeId')));
    expect(function, isNot(contains('assignmentData')));
  });
}
