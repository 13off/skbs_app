import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Контракт также служит безопасной точкой запуска штатной Web/PWA-сборки.
void main() {
  test('touch feedback stays responsive without glow painters', () {
    final pressable = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();

    expect(pressable, isNot(contains('class _TouchGlowPainter')));
    expect(pressable, isNot(contains('RadialGradient(')));
    expect(pressable, isNot(contains('glowController')));
    expect(pressable, isNot(contains('triggerGlow')));
    expect(pressable, contains('AnimatedSlide('));
    expect(pressable, contains('AnimatedScale('));
    expect(pressable, contains('ClipRRect('));
    expect(pressable, contains('HapticFeedback.selectionClick()'));
    expect(pressable, contains('Curves.easeOutBack'));
    expect(pressable, contains('disableAnimations'));
  });

  test('bottom navigation uses spring selection without rebuilding routes', () {
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();

    expect(navigation, contains('TweenAnimationBuilder<double>'));
    expect(navigation, contains('Curves.easeOutBack'));
    expect(navigation, contains("ValueKey('professional-bottom-navigation')"));
    expect(
      navigation,
      contains("ValueKey('professional-bottom-navigation-panel')"),
    );
    expect(navigation, contains('NavigationSession.writeTabIndex'));
  });

  test('общая загрузка использует прежний спокойный индикатор', () {
    final loading = File(
      'lib/widgets/premium_surfaces_v3.dart',
    ).readAsStringSync();

    expect(loading, contains('Подготавливаем рабочее пространство'));
    expect(loading, contains('PremiumBrandMark(size: 98'));
    expect(loading, contains('PremiumDots('));
    expect(loading, contains('width: 300'));
    expect(loading, isNot(contains('AppConstructionLoader')));
    expect(loading, isNot(contains('_ConstructionLoaderPainter')));
    expect(loading, isNot(contains('controller.repeat()')));
    expect(loading, isNot(contains('CustomPaint(')));
  });
}
