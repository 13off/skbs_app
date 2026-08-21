import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Контракт также запускает штатную Web/PWA-публикацию Liquid-интерфейса.
void main() {
  test('Liquid Glass is limited to safe shared surfaces', () {
    final liquid = File('lib/widgets/liquid_glass.dart').readAsStringSync();
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();
    final page = File('lib/widgets/app_page.dart').readAsStringSync();
    final cards = File('lib/widgets/premium_ui_v2.dart').readAsStringSync();
    final viewport = File('lib/app/app_scale_viewport.dart').readAsStringSync();

    expect(liquid, contains('class LiquidGlassSurface'));
    expect(liquid, contains('BackdropFilter('));
    expect(navigation, contains('LiquidGlassSurface('));
    expect(
      navigation,
      contains("ValueKey('professional-bottom-navigation-panel')"),
    );
    expect(navigation, contains('MaterialType.transparency'));
    expect(page, contains('class AppPageHeader'));
    expect(page, contains('blur: !kIsWeb || isDesktop'));
    expect(cards, contains('blur: false'));
    expect(
      cards,
      isNot(contains('BackdropFilter(')),
      reason: 'Повторяющиеся рабочие карточки не должны размывать фон.',
    );
    expect(viewport, isNot(contains('FilterQuality.none')));
    expect(
      navigation,
      contains("ValueKey('professional-bottom-navigation-items')"),
    );
  });
}
