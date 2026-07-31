import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('все роли используют крупный единый визуальный масштаб', () {
    final tokens = File('lib/app/app_ui_tokens.dart').readAsStringSync();
    final page = File('lib/widgets/app_page.dart').readAsStringSync();
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();
    final premium = File('lib/widgets/premium_ui_v2.dart').readAsStringSync();

    expect(tokens, contains('pageHeaderMinHeight = 68'));
    expect(tokens, contains('pageHeaderActionSize = 54'));
    expect(tokens, contains('controlHeight = 56'));
    expect(tokens, contains('cardRadius = 28'));
    expect(page, contains('if (cleanSubtitle.isNotEmpty)'));
    expect(page, contains('alignment: Alignment.centerRight'));
    expect(premium, contains('pressedScale: 0.965'));
    expect(
      navigation,
      contains("key: const ValueKey('professional-bottom-navigation')"),
    );
    expect(navigation, contains('blurSigma: isDesktop ? 20 : 16'));
  });

  test('главная сотрудника остаётся функциональной с одной рабочей кнопкой', () {
    final home = File(
      'lib/features/employee/presentation/employee_home_screen.dart',
    ).readAsStringSync();
    final button = File(
      'lib/features/employee/presentation/premium_round_work_button.dart',
    ).readAsStringSync();

    expect(home, contains('await runtime.start(employeeId)'));
    expect(home, contains('await runtime.finish()'));
    expect(home, contains('PremiumRoundWorkButton('));
    expect(home, isNot(contains('FilledButton.tonalIcon(')));
    expect(
      button,
      contains("widget.active ? 'Завершить работу' : 'Начать работу'"),
    );
    expect(button, contains('dimension = width < 390 ? 244.0 : 272.0'));
    expect(button, contains('idlePulseController.repeat(reverse: true)'));
    expect(button, contains('shazamWaveController.repeat('));
    expect(button, contains('class _ShazamWaveRing'));
    expect(button, contains('class _PremiumButtonBody'));
    expect(button, contains('class _WorkEmblem'));
    expect(button, contains('Icons.construction_rounded'));
    expect(button, isNot(contains('CircularProgressIndicator')));
    expect(button, isNot(contains('play_arrow_rounded')));
    expect(button, contains('AnimatedSlide('));
    expect(button, contains('SweepGradient('));
    expect(button, contains('AnimatedSwitcher('));
    expect(home, isNot(contains('Нажмите кнопку перед началом рабочего дня.')));
  });

  test('профиль отчёты и табель используют одинаковые крупные карточки', () {
    final profile = File(
      'lib/features/employee/presentation/employee_identity_profile_screen.dart',
    ).readAsStringSync();
    final reports = File(
      'lib/features/reports/presentation/manager_reports_screen.dart',
    ).readAsStringSync();
    final timesheet = File(
      'lib/screens/timesheet/timesheet_view.dart',
    ).readAsStringSync();

    expect(profile, contains('width: 104'));
    expect(profile, contains("'История задач'"));
    expect(profile, contains('Icons.settings_rounded, size: 27'));
    expect(profile, contains('textWidthBasis: TextWidthBasis.parent'));
    expect(profile, isNot(contains('Сотрудник · просмотр руководителя')));
    expect(reports, contains('Widget routesButton()'));
    expect(reports, isNot(contains('Единый центр аналитики руководителя')));
    expect(timesheet, contains('BoxConstraints(maxWidth: 460)'));
    expect(timesheet, contains('PremiumWorkCard('));
  });
}
