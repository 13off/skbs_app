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

  test('premium pressables use the same hover and press motion', () {
    final source = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();

    expect(source, contains('this.hoverScale = AppMotion.hoverScale'));
    expect(source, contains('AppMotion.interactionCurve'));
    expect(source, contains('FocusableActionDetector'));
  });

  test('shell keeps the last known-good visible tab structure', () {
    final source = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();

    expect(source, contains('CupertinoPageRoute<void>'));
    expect(source, contains('PageView.builder'));
    expect(
      source,
      contains('return buildRootPage(index, selectedObjectName);'),
    );
    expect(source, isNot(contains('final isDesktop = screenWidth >= 760')));
  });
}
