import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const homePath =
      'lib/features/employee/presentation/employee_home_screen.dart';
  const profilePath = 'lib/screens/profile_screen.dart';
  const mainPath = 'lib/screens/main_screen.dart';

  test('сотрудник получает главную задачи и профиль в нижней панели', () {
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(wrapper, contains("label: 'Главная'"));
    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains("label: 'Профиль'"));
    expect(wrapper, contains('EmployeeHomeScreen'));
    expect(wrapper, contains('EmployeeTasksScreen'));
    expect(wrapper, contains('ProfileScreen(profile: contentProfile)'));
    expect(wrapper, isNot(contains('rootHeaderTrailingBuilder:')));
  });

  test('на главной есть большая круглая кнопка начала работы', () {
    final home = File(homePath).readAsStringSync();

    expect(home, contains("title: 'Главная'"));
    expect(home, contains("'Начать работу'"));
    expect(home, contains('shape: const CircleBorder()'));
    expect(home, contains('dimension: 228'));
    expect(home, contains('runtime.start(employeeId)'));
    expect(home, contains('runtime.finish()'));
  });

  test('история задач находится в профиле, настройки открывает шестерёнка', () {
    final profile = File(profilePath).readAsStringSync();

    expect(profile, contains('if (profile.isEmployee)'));
    expect(profile, contains('EmployeeWorkTaskHistoryScreen'));
    expect(profile, contains("title: 'История задач'"));
    expect(profile, contains("tooltip: 'Настройки'"));
    expect(profile, isNot(contains("title: 'Настройки'")));
    expect(profile, contains('suppressAutomaticBackButton: true'));
  });

  test('предпросмотр сохраняет возврат к руководителю', () {
    final main = File(mainPath).readAsStringSync();

    expect(main, contains("label: const Text('К руководителю')"));
    expect(main, contains('RolePreviewController.showAdmin'));
  });
}
