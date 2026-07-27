import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Этот контракт также служит безопасной точкой штатной Web/PWA-публикации.
// Повторная публикация версии без глобального и локального touch-glow.
void main() {
  test('global touch glow is removed while viewport scaling stays intact', () {
    final viewport = File(
      'lib/app/app_scale_viewport.dart',
    ).readAsStringSync();
    final glowFile = File('lib/widgets/global_touch_glow.dart');

    expect(viewport, isNot(contains('AppTouchGlowOverlay')));
    expect(viewport, isNot(contains('global_touch_glow.dart')));
    expect(glowFile.existsSync(), isFalse);
    expect(viewport, contains('Transform.scale('));
    expect(viewport, contains('mediaQuery.copyWith('));
    expect(viewport, contains('systemGestureInsets'));
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
