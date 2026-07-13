import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main shell keeps visible screens and professional navigation', () {
    final shell = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();
    final legacyUi = File(
      'lib/widgets/premium_ui_v2.dart',
    ).readAsStringSync();
    final pressable = File(
      'lib/widgets/premium_pressable_v3.dart',
    ).readAsStringSync();

    expect(shell, contains("show CupertinoPageRoute"));
    expect(shell, contains('return CupertinoPageRoute<void>('));
    expect(shell, contains('return buildRootPage(index, selectedObjectName);'));
    expect(shell, contains('final isDesktop = screenWidth >= 880'));
    expect(shell, contains('constraints: BoxConstraints(maxWidth: maxWidth)'));
    expect(legacyUi, contains('return unified.PremiumPressable('));
    expect(pressable, contains('void invokeAction()'));
    expect(pressable, isNot(contains('void activate()')));
  });
}
