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

  test('shell uses unified routes and adaptive professional bar', () {
    final source = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();

    expect(source, contains('MaterialPageRoute<void>'));
    expect(source, isNot(contains('CupertinoPageRoute')));
    expect(source, contains('final isDesktop = screenWidth >= 760'));
    expect(source, contains('constraints: BoxConstraints(maxWidth: maxWidth)'));
    expect(source, contains('hoverScale: selected ? 1.012 : 1.026'));
  });
}
