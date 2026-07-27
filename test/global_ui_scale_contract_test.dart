import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the entire app is rendered through one persisted scale viewport', () {
    final main = File('lib/main.dart').readAsStringSync();
    final controller = File(
      'lib/app/theme_controller.dart',
    ).readAsStringSync();
    final viewport = File(
      'lib/app/app_scale_viewport.dart',
    ).readAsStringSync();

    expect(main, contains("import 'app/app_scale_viewport.dart';"));
    expect(main, contains('builder: (context, child) => AppScaleViewport('));
    expect(main, contains('scale: themeController.uiScale'));
    expect(controller, contains("_scalePreferenceKey = 'app_ui_scale'"));
    expect(controller, contains('defaultUiScale = 0.90'));
    expect(controller, contains('preferences.setDouble(_scalePreferenceKey'));
    expect(viewport, contains('Transform.scale('));
    expect(viewport, contains('MediaQuery('));
    expect(viewport, contains('OverflowBox('));
  });

  test('scale is configured inside settings without a floating overlay', () {
    final controller = File(
      'lib/app/theme_controller.dart',
    ).readAsStringSync();
    final viewport = File(
      'lib/app/app_scale_viewport.dart',
    ).readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    for (final option in <String>['0.80', '0.90', '1.00', '1.10', '1.20']) {
      expect(controller, contains(option));
    }
    expect(settings, contains("'Масштаб приложения'"));
    expect(settings, contains('AppThemeController.uiScaleOptions'));
    expect(settings, contains('controller.setUiScale(value)'));
    expect(viewport, isNot(contains('_AppScaleControls')));
    expect(viewport, isNot(contains("tooltip: 'Уменьшить масштаб'")));
  });

  test('candidate CRM uses full width without stretching every page', () {
    final tokens = File('lib/app/app_ui_tokens.dart').readAsStringSync();
    final page = File('lib/widgets/app_page.dart').readAsStringSync();

    expect(tokens, contains('pageContentWidth = 1180'));
    expect(page, contains("isDesktop && title == 'Кандидаты'"));
    expect(page, contains('? double.infinity'));
    expect(
      page,
      contains('BoxConstraints(maxWidth: effectiveMaxContentWidth)'),
    );
    expect(page, contains('this.maxContentWidth = AppUi.pageContentWidth'));
  });
}
