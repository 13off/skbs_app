import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard buttons use one motion system', () {
    final source = File('lib/app/app_theme.dart').readAsStringSync();

    expect(source, contains('AppMotion.hoverScale'));
    expect(source, contains('backgroundBuilder: buttonSurface('));
    expect(source, contains('filledButtonStyle'));
    expect(source, contains('outlinedButtonStyle'));
    expect(source, contains('textButtonStyle'));
    expect(source, contains('iconButtonStyle'));
  });

  test('both premium pressables use identical motion constants', () {
    final legacy = File('lib/widgets/premium_ui_v2.dart').readAsStringSync();
    final current = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();

    for (final source in <String>[legacy, current]) {
      expect(source, contains('this.pressedScale = AppMotion.pressedScale'));
      expect(source, contains('this.hoverScale = AppMotion.hoverScale'));
      expect(source, contains('AppMotion.interactionCurve'));
      expect(source, contains('FocusableActionDetector'));
      expect(source, contains('void invokeAction()'));
      expect(source, isNot(contains('void activate()')));
    }
  });

  test('shell body remains unchanged before bottom navigation', () {
    final source = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();
    final barStart = source.indexOf(
      'class _PremiumBottomBar extends StatelessWidget',
    );
    final stableShell = source.substring(0, barStart);

    expect(stableShell, contains('CupertinoPageRoute<void>'));
    expect(stableShell, contains('PageView.builder'));
    expect(
      stableShell,
      contains('return buildRootPage(index, selectedObjectName);'),
    );
    expect(source, contains('return ProfessionalBottomNavigation('));
  });
}
