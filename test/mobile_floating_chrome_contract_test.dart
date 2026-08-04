import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile timesheet save button uses navigation-safe clearance', () {
    final view = File(
      'lib/screens/timesheet/timesheet_view.dart',
    ).readAsStringSync();
    final tokens = File('lib/app/app_ui_tokens.dart').readAsStringSync();

    expect(view, contains("key: const ValueKey('timesheet-floating-save')"));
    expect(view, contains('AppUi.floatingActionBottom(context)'));
    expect(view, contains('AppUi.floatingActionListBottomPadding(context)'));
    expect(view, contains('bottom: floatingBottom'));
    expect(view, isNot(contains('bottom: 14')));
    expect(tokens, contains('navigationTotalHeight(BuildContext context)'));
    expect(tokens, contains('MediaQuery.viewPaddingOf(context).bottom'));
    expect(view, contains('PremiumActionButton('));
    expect(
      view,
      isNot(contains('constraints: const BoxConstraints(maxWidth: 460)')),
    );
    expect(view, isNot(contains('PremiumWorkCard(')));
  });

  test('bottom navigation has one bounded glass panel', () {
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();

    expect(
      navigation,
      contains("key: const ValueKey('professional-bottom-navigation-panel')"),
    );
    expect(
      navigation,
      contains("key: const ValueKey('professional-bottom-navigation-items')"),
    );
    expect(navigation, contains('LiquidGlassSurface('));
    expect(navigation, contains('MaterialType.transparency'));
  });
}
