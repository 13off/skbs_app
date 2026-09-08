import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('PWA keeps the page background full width and insets its panels', () {
    final main = source('lib/main.dart');
    final page = source('lib/widgets/app_page.dart');
    final tokens = source('lib/app/app_ui_tokens.dart');

    expect(main, contains('builder: (context, child) => AppScaleViewport('));
    expect(main, isNot(contains('PwaDesktopPageFrame(')));
    expect(page, isNot(contains('PwaDesktopPageFrame.isApplied(context)')));
    expect(page, contains('? AppUi.pageDesktopHorizontalPadding'));
    expect(tokens, contains('pageDesktopHorizontalPadding = 48'));
  });

  test('compact desktop bottom navigation stays near twenty centimetres', () {
    final tokens = source('lib/app/app_ui_tokens.dart');
    final navigation = source(
      'lib/widgets/professional_bottom_navigation.dart',
    );

    expect(tokens, contains('desktopNavigationMaxWidth = 945'));
    expect(navigation, contains('AppUi.desktopNavigationMaxWidth'));
    expect(navigation, contains('child: Center('));
    expect(navigation, contains('horizontal: isDesktop ? 14 : 4'));
    expect(navigation, contains('fontSize: 13'));
  });
}
