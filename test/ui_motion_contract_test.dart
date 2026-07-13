import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard buttons use one motion surface', () {
    final source = File('lib/app/app_theme.dart').readAsStringSync();

    expect(source, contains('AppMotion.hoverScale'));
    expect(source, contains('backgroundBuilder: buttonSurface('));
    expect(source, contains('filledButtonStyle'));
    expect(source, contains('outlinedButtonStyle'));
    expect(source, contains('textButtonStyle'));
    expect(source, contains('iconButtonStyle'));
  });

  test('legacy and current premium buttons use one implementation', () {
    final canonical = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();
    final legacy = File('lib/widgets/premium_ui_v2.dart').readAsStringSync();

    expect(canonical, contains('this.hoverScale = AppMotion.hoverScale'));
    expect(canonical, contains('AppMotion.interactionCurve'));
    expect(canonical, contains('FocusableActionDetector'));
    expect(legacy, contains("premium_pressable_v3.dart' as unified"));
    expect(legacy, contains('return unified.PremiumPressable('));
  });

  test('shell keeps visible tabs and only polishes bottom navigation', () {
    final source = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();
    final barStart = source.indexOf(
      'class _PremiumBottomBar extends StatelessWidget',
    );
    final stableShell = source.substring(0, barStart);
    final bottomBar = source.substring(barStart);

    expect(stableShell, contains('CupertinoPageRoute<void>'));
    expect(stableShell, contains('PageView.builder'));
    expect(
      stableShell,
      contains('return buildRootPage(index, selectedObjectName);'),
    );
    expect(bottomBar, contains('final isDesktop = screenWidth >= 880'));
    expect(
      bottomBar,
      contains('constraints: BoxConstraints(maxWidth: maxWidth)'),
    );
    expect(bottomBar, contains('hoverScale: selected ? 1.008 : 1.016'));
  });
}
