import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile timesheet save button has no surrounding dark card', () {
    final view = File(
      'lib/screens/timesheet/timesheet_view.dart',
    ).readAsStringSync();

    expect(view, contains("key: const ValueKey('timesheet-floating-save')"));
    expect(view, contains('PremiumActionButton('));
    expect(
      view,
      isNot(contains('constraints: const BoxConstraints(maxWidth: 460)')),
    );
    expect(view, isNot(contains('PremiumWorkCard(')));
  });

  test('bottom navigation has no full-width glass panel', () {
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();

    expect(
      navigation,
      contains("key: const ValueKey('professional-bottom-navigation-items')"),
    );
    expect(
      navigation,
      isNot(contains("key: const ValueKey('professional-bottom-navigation-panel')")),
    );
    expect(navigation, isNot(contains('LiquidGlassSurface(')));
  });
}
