import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Контракт запускает штатную Web/PWA-публикацию после изменения масштаба.
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

  test('scale controls cover compact normal and enlarged modes', () {
    final controller = File(
      'lib/app/theme_controller.dart',
    ).readAsStringSync();
    final viewport = File(
      'lib/app/app_scale_viewport.dart',
    ).readAsStringSync();

    for (final option in <String>['0.80', '0.90', '1.00', '1.10', '1.20']) {
      expect(controller, contains(option));
    }
    expect(viewport, contains("tooltip: 'Уменьшить масштаб'"));
    expect(viewport, contains("tooltip: 'Увеличить масштаб'"));
    expect(viewport, contains("message: 'Сбросить масштаб до 90%'"));
    expect(viewport, contains('controller.decreaseUiScale()'));
    expect(viewport, contains('controller.increaseUiScale()'));
    expect(viewport, contains('controller.resetUiScale()'));
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
