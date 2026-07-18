import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark theme is controlled only from profile and persists locally', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final controller = File(
      'lib/app/theme_controller.dart',
    ).readAsStringSync();
    final darkTheme = File(
      'lib/app/app_dark_theme.dart',
    ).readAsStringSync();
    final appPage = File('lib/widgets/app_page.dart').readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();

    expect(mainSource, contains('darkTheme: AppDarkTheme.theme'));
    expect(mainSource, contains('themeMode: themeController.themeMode'));
    expect(mainSource, contains('AppThemeController.instance.initialize()'));

    expect(controller, contains('SharedPreferences.getInstance()'));
    expect(controller, contains("'app_theme_mode'"));
    expect(controller, contains('ThemeMode.dark'));
    expect(controller, contains('Future<void> toggle()'));

    expect(darkTheme, contains('brightness: Brightness.dark'));
    expect(darkTheme, contains('navigationBarTheme'));
    expect(darkTheme, contains('switchTheme'));

    expect(profile, contains('headerTrailing: buildThemeToggle()'));
    expect(profile, contains('Icons.dark_mode_rounded'));
    expect(profile, contains('Icons.light_mode_rounded'));
    expect(profile, contains('onPressed: controller.toggle'));

    expect(appPage, isNot(contains('AppThemeController')));
    expect(appPage, isNot(contains('Icons.dark_mode_rounded')));
  });
}
