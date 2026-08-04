import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared bottom navigation stays translucent on every page', () {
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();
    final liquid = File(
      'lib/widgets/liquid_glass.dart',
    ).readAsStringSync();

    expect(liquid, contains('final Gradient? gradient;'));
    expect(liquid, contains('final resolvedGradient = gradient ??'));
    expect(liquid, contains('gradient: resolvedGradient'));

    expect(navigation, contains('_darkNavigationPanelGradient'));
    expect(navigation, contains('_lightNavigationPanelGradient'));
    expect(navigation, contains('Color(0x66232C35)'));
    expect(navigation, contains('Color(0x66F1F4F7)'));
    expect(navigation, contains('Color(0xB3353B42)'));
    expect(navigation, contains('Color(0x992C3640)'));
    expect(navigation, contains('Color(0x8011171E)'));
    expect(navigation, contains('blurSigma: isDesktop ? 24 : 20'));
    expect(navigation, isNot(contains('Color(0xFF232C35)')));
    expect(navigation, isNot(contains('Color(0xF7353B42)')));
    expect(
      navigation,
      contains(
        'gradient: dark\n                    ? _darkNavigationPanelGradient\n                    : _lightNavigationPanelGradient',
      ),
    );
    expect(
      navigation,
      contains("ValueKey('professional-bottom-navigation-panel')"),
    );
    expect(navigation, contains('LiquidGlassSurface('));
    expect(navigation, contains('blur: true'));
  });
}
