import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('AppСтрой uses one shared page geometry and header', () {
    final tokens = source('lib/app/app_ui_tokens.dart');
    final page = source('lib/widgets/app_page.dart');
    final premium = source('lib/widgets/premium_ui_v2.dart');
    final specialist = source(
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    );

    expect(tokens, contains('class AppUi'));
    expect(tokens, contains('pageHeaderMinHeight'));
    expect(tokens, contains('controlHeight = 48'));
    expect(tokens, contains('cardRadius = 22'));

    expect(page, contains('AppUi.pageHeaderMinHeight'));
    expect(page, contains("cleanSubtitle.isEmpty ? ' ' : cleanSubtitle"));
    expect(page, contains('AppSurfaceBackdrop'));
    expect(page, contains('AppUi.pageContentWidth'));

    expect(premium, contains('this.radius = AppUi.cardRadius'));
    expect(premium, contains('height: AppUi.controlHeight'));
    expect(premium, contains('return AppSurfaceBackdrop(child: child)'));

    expect(specialist, contains('return AppPage('));
    expect(
      specialist,
      contains('maxContentWidth: AppUi.specialistContentWidth'),
    );
    expect(specialist, isNot(contains('BoxConstraints(maxWidth: 1460)')));
  });

  test('light, dark and depth themes share controls and card radii', () {
    final light = source('lib/app/app_theme.dart');
    final dark = source('lib/app/app_dark_theme.dart');
    final depth = source('lib/app/premium_depth_theme.dart');

    for (final theme in <String>[light, dark, depth]) {
      expect(theme, contains('AppUi.controlRadius'));
      expect(theme, contains('AppUi.cardRadius'));
    }
    expect(light, contains('AppUi.controlHeight'));
    expect(dark, contains('AppUi.controlHeight'));
  });

  test('design system is documented for future screens', () {
    final guide = source('docs/app-ui-design-system.md');

    expect(guide, contains('AppPage'));
    expect(guide, contains('AppUi'));
    expect(guide, contains('PremiumWorkCard'));
    expect(guide, contains('flutter analyze'));
  });

  test('legacy home card no longer introduces a separate orange style', () {
    final card = source('lib/widgets/home_card.dart');

    expect(card, contains('PremiumWorkCard'));
    expect(card, contains('AppAdaptivePalette.accent'));
    expect(card, isNot(contains('0xFFFF7A1A')));
    expect(card, isNot(contains('Colors.grey.shade100')));
  });
}
