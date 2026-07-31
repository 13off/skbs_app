import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const homePath =
      'lib/features/employee/presentation/employee_home_screen.dart';
  const workButtonPath =
      'lib/features/employee/presentation/premium_round_work_button.dart';
  const identityProfilePath =
      'lib/features/employee/presentation/employee_identity_profile_screen.dart';
  const mainPath = 'lib/screens/main_screen.dart';

  test('сотрудник получает главную задачи и профиль в нижней панели', () {
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(wrapper, contains("label: 'Главная'"));
    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains("label: 'Профиль'"));
    expect(wrapper, contains('EmployeeHomeScreen'));
    expect(wrapper, contains('EmployeeTasksScreen'));
    expect(wrapper, contains('EmployeeIdentityProfileScreen'));
    expect(wrapper, isNot(contains('rootHeaderTrailingBuilder:')));
  });

  test('на главной есть большая объёмная кнопка начала работы', () {
    final home = File(homePath).readAsStringSync();
    final button = File(workButtonPath).readAsStringSync();

    expect(home, contains("title: 'Главная'"));
    expect(home, contains('PremiumRoundWorkButton('));
    expect(home, contains('runtime.start(employeeId)'));
    expect(home, contains('runtime.finish()'));
    expect(button, contains("'Начать работу'"));
    expect(button, contains('dimension = width < 390 ? 244.0 : 272.0'));
    expect(button, contains('pulseController.repeat(reverse: true)'));
    expect(button, contains('Transform.scale('));
    expect(button, contains('RadialGradient('));
    expect(button, isNot(contains('top: 22')));
  });

  test('история задач находится в профиле, настройки открывает шестерёнка', () {
    final profile = File(identityProfilePath).readAsStringSync();

    expect(profile, contains('EmployeeWorkTaskHistoryScreen'));
    expect(profile, contains("'История задач'"));
    expect(profile, contains("tooltip: 'Настройки'"));
    expect(profile, contains('suppressAutomaticBackButton: true'));
    expect(profile, contains('textWidthBasis: TextWidthBasis.parent'));
    expect(profile, contains('alignment: Alignment.center'));
  });

  test('предпросмотр сохраняет возврат к руководителю', () {
    final main = File(mainPath).readAsStringSync();

    expect(main, contains("label: const Text('К руководителю')"));
    expect(main, contains('RolePreviewController.showAdmin'));
  });
}
