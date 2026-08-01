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

  test('одна стеклянная плавная кнопка запускает и завершает рабочий день', () {
    final home = File(homePath).readAsStringSync();
    final button = File(workButtonPath).readAsStringSync();

    expect(home, contains("title: 'Главная'"));
    expect(home, contains('PremiumRoundWorkButton('));
    expect(home, contains('runtime.start(employeeId)'));
    expect(home, contains('runtime.finish()'));
    expect(home, contains('active\n                            ? finishDay'));
    expect(home, isNot(contains('FilledButton.tonalIcon(')));

    expect(
      button,
      contains("return widget.active ? 'Завершить работу' : 'Начать работу';"),
    );
    expect(button, contains('dimension = width < 390 ? 244.0 : 272.0'));
    expect(button, contains('Duration(milliseconds: 4200)'));
    expect(button, contains('Duration(milliseconds: 2400)'));
    expect(button, contains('idlePulseController.repeat(reverse: true)'));
    expect(button, contains('shazamWaveController.repeat('));
    expect(button, contains('class _ShazamWaveRing'));
    expect(button, contains('staggeredWave(waveValue, 0.14)'));
    expect(button, contains('staggeredWave(waveValue, 0.28)'));
    expect(button, contains('staggeredWave(waveValue, 0.42)'));
    expect(button, contains('staggeredWave(waveValue, 0.56)'));
    expect(button, contains('Curves.easeInOutSine'));
    expect(button, contains('ui.ImageFilter.blur'));
    expect(button, contains('class _MatteTexturePainter'));
    expect(button, contains('HapticFeedback.mediumImpact()'));
    expect(button, contains('SweepGradient('));
    expect(button, contains('Icons.stop_rounded'));
    expect(button, contains('Icons.construction_rounded'));
    expect(button, isNot(contains('play_arrow_rounded')));
    expect(button, isNot(contains('CircularProgressIndicator')));
    expect(button, contains('AnimatedSwitcher('));
    expect(button, contains('key: ValueKey<String>(actionLabel)'));
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
