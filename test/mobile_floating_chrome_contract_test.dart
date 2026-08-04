import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile timesheet save button follows navigation and safe area', () {
    final view = File(
      'lib/screens/timesheet/timesheet_view.dart',
    ).readAsStringSync();
    final tokens = File('lib/app/app_ui_tokens.dart').readAsStringSync();
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();

    expect(view, contains("key: const ValueKey('timesheet-floating-save')"));
    expect(view, contains('AppUi.bottomActionOffset(context)'));
    expect(view, contains('AppUi.bottomActionContentPadding('));
    expect(view, contains('bottom: saveButtonBottom'));
    expect(view, isNot(contains('bottom: 14')));
    expect(view, isNot(contains('EdgeInsets.fromLTRB(18, 18, 18, 118)')));
    expect(view, contains('PremiumActionButton('));
    expect(
      view,
      isNot(contains('constraints: const BoxConstraints(maxWidth: 460)')),
    );
    expect(view, isNot(contains('PremiumWorkCard(')));

    expect(tokens, contains('MediaQuery.viewPaddingOf(context).bottom'));
    expect(tokens, contains('bottomNavigationHeight(context)'));
    expect(tokens, contains('bottomActionNavigationGap'));
    expect(
      navigation,
      contains('height: AppUi.bottomNavigationHeight(context)'),
    );
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
