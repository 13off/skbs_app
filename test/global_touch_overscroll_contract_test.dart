import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Этот контракт также служит безопасной точкой штатной Web/PWA-публикации.
// Повторная точка публикации мягкого фонового касания и чата без кнопки ИИ.
void main() {
  test('global touch glow stays broad, soft and visually unobtrusive', () {
    final viewport = File(
      'lib/app/app_scale_viewport.dart',
    ).readAsStringSync();
    final glow = File(
      'lib/widgets/global_touch_glow.dart',
    ).readAsStringSync();

    expect(viewport, contains('AppTouchGlowOverlay'));
    expect(glow, contains('Listener('));
    expect(glow, contains('onPointerDown'));
    expect(glow, contains('onPointerMove'));
    expect(glow, contains('StackFit.expand'));
    expect(glow, contains('RadialGradient('));
    expect(glow, contains('BlendMode.softLight'));
    expect(glow, contains('620.0'));
    expect(glow, contains('0.024'));
    expect(glow, contains('IgnorePointer('));
    expect(glow, contains('RepaintBoundary('));
    expect(glow, contains('disableAnimations'));
    expect(glow, isNot(contains('PaintingStyle.stroke')));
  });

  test('all scrollable pages can stretch past both boundaries and spring back', () {
    final scroll = File(
      'lib/app/premium_scroll_behavior.dart',
    ).readAsStringSync();

    expect(scroll, contains('class PremiumBouncingScrollPhysics'));
    expect(scroll, contains('BouncingScrollPhysics'));
    expect(scroll, contains('AlwaysScrollableScrollPhysics'));
    expect(scroll, contains('frictionFactor'));
    expect(scroll, contains('SpringDescription('));
    expect(scroll, isNot(contains('ClampingScrollPhysics')));
  });
}
