import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web PWA uses the fast interaction and scrolling contract', () {
    final theme = File('lib/app/app_theme.dart').readAsStringSync();
    final scroll = File(
      'lib/app/premium_scroll_behavior.dart',
    ).readAsStringSync();
    final pressable = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();
    final legacyPressable = File(
      'lib/widgets/premium_ui_v2_legacy.dart',
    ).readAsStringSync();
    final surfaces = File(
      'lib/widgets/premium_ui_v2.dart',
    ).readAsStringSync();
    final page = File('lib/widgets/app_page.dart').readAsStringSync();
    final scale = File(
      'lib/app/app_scale_viewport.dart',
    ).readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(theme, contains('static const hover = Duration(milliseconds: 70)'));
    expect(theme, contains('static const regular = Duration(milliseconds: 95)'));
    expect(theme, contains('route.isFirst || kIsWeb || desktopPlatform'));
    expect(scroll, contains('ClampingScrollPhysics'));
    expect(scroll, contains('if (kIsWeb || desktopPlatform)'));

    for (final source in <String>[pressable, legacyPressable]) {
      final interaction = source.split('class PremiumActionButton').first;
      expect(interaction, isNot(contains('AnimatedSlide(')));
      expect(interaction, isNot(contains('ClipRRect(')));
      expect(interaction, isNot(contains('boxShadow: activeHover')));
      expect(interaction, contains('DecorationPosition.foreground'));
    }

    expect(surfaces, contains('return RepaintBoundary('));
    expect(page, contains('Positioned.fill(
          child: RepaintBoundary('));
    expect(scale, contains('filterQuality: FilterQuality.none'));
    expect(
      mainSource,
      contains('themeAnimationDuration: const Duration(milliseconds: 110)'),
    );
  });
}
