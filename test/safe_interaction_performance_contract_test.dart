import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Отдельный контракт также служит безопасной точкой запуска Web/PWA-сборки.
void main() {
  test('safe interaction tuning keeps the visual renderer intact', () {
    final viewport = File('lib/app/app_scale_viewport.dart').readAsStringSync();
    final pressable = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();
    final theme = File('lib/app/app_theme.dart').readAsStringSync();

    expect(viewport, isNot(contains('FilterQuality.none')));
    expect(pressable, contains('ClipRRect('));
    expect(pressable, contains('AnimatedSlide('));
    expect(pressable, contains('AnimatedScale('));
    expect(pressable, contains('blurRadius: 24'));
    expect(navigation, contains("ValueKey('professional-bottom-navigation')"));
    expect(
      navigation,
      contains("ValueKey('professional-bottom-navigation-items')"),
    );
    expect(navigation, contains('MaterialType.transparency'));
    expect(theme, contains('GoogleFonts.manropeTextTheme'));
    expect(theme, contains('static const background = Color(0xFFF5F4F1)'));
  });

  test('desktop interactions remain fast and use controlled overscroll', () {
    final pressable = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();
    final scroll = File(
      'lib/app/premium_scroll_behavior.dart',
    ).readAsStringSync();

    expect(pressable, contains('_hoverDuration'));
    expect(pressable, contains('_releaseDuration'));
    expect(pressable, contains('Duration(milliseconds: 85)'));
    expect(pressable, contains('Duration(milliseconds: 95)'));
    expect(scroll, contains('PremiumBouncingScrollPhysics'));
    expect(scroll, contains('AlwaysScrollableScrollPhysics'));
    expect(scroll, contains('SpringDescription('));
    expect(scroll, isNot(contains('GlowingOverscrollIndicator')));
  });
}
