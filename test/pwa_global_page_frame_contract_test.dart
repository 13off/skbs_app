import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('one PWA frame covers every application page', () {
    final main = source('lib/main.dart');
    final frame = source('lib/widgets/pwa_desktop_page_frame.dart');
    final page = source('lib/widgets/app_page.dart');

    expect(main, contains('builder: (context, child) => PwaDesktopPageFrame('));
    expect(main, contains('child: AppScaleViewport('));
    expect(frame, contains('horizontal = AppUi.pageDesktopHorizontalPadding'));
    expect(frame, contains('media.copyWith('));
    expect(page, contains('PwaDesktopPageFrame.isApplied(context)'));
    expect(page, isNot(contains('Color(0xFF080B0F)')));
    expect(page, contains('gradient: dark'));
    expect(page, contains('? null'));
  });

  test('desktop bottom navigation stays near twenty centimetres', () {
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
