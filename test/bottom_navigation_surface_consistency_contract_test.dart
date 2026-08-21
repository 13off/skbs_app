import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'shared bottom navigation stays translucent and graphite on every page',
    () {
      final navigation = File(
        'lib/widgets/professional_bottom_navigation.dart',
      ).readAsStringSync();
      final liquid = File('lib/widgets/liquid_glass.dart').readAsStringSync();

      expect(liquid, contains('final Gradient? gradient;'));
      expect(
        liquid,
        matches(RegExp(r'final\s+resolvedGradient\s*=\s*gradient\s*\?\?')),
      );
      expect(liquid, contains('gradient: resolvedGradient'));

      // Web/PWA keeps the established glass palette and geometry.
      expect(navigation, contains('_darkNavigationPanelGradient'));
      expect(navigation, contains('_lightNavigationPanelGradient'));
      expect(navigation, contains('Color(0x8047525D)'));
      expect(navigation, contains('Color(0x66F1F4F7)'));
      expect(navigation, contains('Color(0xCC5B646E)'));
      expect(navigation, contains('Color(0xB34A5662)'));
      expect(navigation, contains('Color(0x99404B56)'));

      // Android/iOS get a dedicated lighter glass branch without altering Web.
      expect(
        navigation,
        contains('final nativeMobile = !kIsWeb && !isDesktop;'),
      );
      expect(navigation, contains('_nativeDarkNavigationPanelTint'));
      expect(navigation, contains('_nativeLightNavigationPanelTint'));
      expect(navigation, contains('_nativeDarkNavigationPanelGradient'));
      expect(navigation, contains('_nativeLightNavigationPanelGradient'));
      expect(
        navigation,
        contains('blurSigma: nativeMobile ? 18 : (isDesktop ? 24 : 20)'),
      );
      expect(navigation, contains('? _nativeDarkNavigationPanelGradient'));
      expect(navigation, contains(': _nativeLightNavigationPanelGradient'));
      expect(navigation, contains('? _darkNavigationPanelGradient'));
      expect(navigation, contains(': _lightNavigationPanelGradient'));

      expect(navigation, isNot(contains('Color(0xFF232C35)')));
      expect(navigation, isNot(contains('Color(0x66232C35)')));
      expect(navigation, isNot(contains('Color(0xF7353B42)')));
      expect(
        navigation,
        contains("ValueKey('professional-bottom-navigation-panel')"),
      );
      expect(navigation, contains('LiquidGlassSurface('));
      expect(navigation, contains('blur: !kIsWeb || isDesktop'));
    },
  );
}
