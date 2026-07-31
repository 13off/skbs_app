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

  test('bottom navigation animates selection without rebuilding routes', () {
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();

    expect(navigation, contains('AnimatedContainer('));
    expect(navigation, contains('AnimatedSwitcher('));
    expect(navigation, contains('Curves.easeOutBack'));
    expect(navigation, contains("ValueKey('professional-bottom-navigation')"));
    expect(
      navigation,
      contains("ValueKey('professional-bottom-navigation-panel')"),
    );
    expect(navigation, contains('NavigationSession.writeTabIndex'));
  });

  test('общая загрузка показывает только вращающийся круг', () {
    final loading = File(
      'lib/widgets/premium_surfaces_v3.dart',
    ).readAsStringSync();

    expect(loading, contains('CircularProgressIndicator('));
    expect(loading, contains('strokeWidth: 2.6'));
    expect(loading, contains('liveRegion: true'));
    expect(loading, isNot(contains('PremiumBrandMark')));
    expect(loading, isNot(contains("Text('AppСтрой'")));
    expect(loading, isNot(contains('PremiumDots(')));
    expect(loading, isNot(contains('AppConstructionLoader')));
    expect(loading, isNot(contains('LiquidGlassSurface')));
  });
}
