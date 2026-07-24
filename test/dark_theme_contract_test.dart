import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/app/app_dark_theme.dart';

void main() {
  double contrast(Color foreground, Color background) {
    final foregroundLuminance = foreground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    final lighter = foregroundLuminance > backgroundLuminance
        ? foregroundLuminance
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance
        ? backgroundLuminance
        : foregroundLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }

  test('dark theme is enabled and persisted by the application controller', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final controller = File(
      'lib/app/theme_controller.dart',
    ).readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(mainSource, contains('darkTheme: AppDarkTheme.theme'));
    expect(mainSource, contains('themeMode: themeController.themeMode'));
    expect(mainSource, contains('AppThemeController.instance.initialize()'));

    expect(controller, contains('static const bool featureEnabled = true'));
    expect(controller, contains('SharedPreferences.getInstance()'));
    expect(controller, contains("'app_theme_mode'"));
    expect(controller, contains("value ? 'dark' : 'light'"));
    expect(controller, contains('ThemeMode.dark'));
    expect(controller, contains('Future<void> toggle()'));
    expect(controller, isNot(contains('if (!featureEnabled)')));

    expect(settings, contains("'Тёмная тема'"));
    expect(settings, contains('Icons.dark_mode_outlined'));
    expect(settings, contains('value: controller.isDark'));
    expect(settings, contains('onChanged: controller.setDark'));
  });

  test('telegram-like dark palette is readable and avoids pure black', () {
    expect(AppDarkTheme.background, const Color(0xFF0E1621));
    expect(AppDarkTheme.surface, const Color(0xFF17212B));
    expect(AppDarkTheme.accent, const Color(0xFF3390EC));
    expect(AppDarkTheme.accentStrong, const Color(0xFF2278BF));
    expect(AppDarkTheme.background, isNot(Colors.black));

    expect(
      contrast(AppDarkTheme.textPrimary, AppDarkTheme.background),
      greaterThanOrEqualTo(7),
    );
    expect(
      contrast(AppDarkTheme.textMuted, AppDarkTheme.background),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(Colors.white, AppDarkTheme.accentStrong),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppDarkTheme.accent, AppDarkTheme.background),
      greaterThanOrEqualTo(4.5),
    );

    final darkThemeSource = File(
      'lib/app/app_dark_theme.dart',
    ).readAsStringSync();
    expect(darkThemeSource, contains('brightness: Brightness.dark'));
    expect(darkThemeSource, contains('backgroundColor: accentStrong'));
    expect(darkThemeSource, contains('indicatorColor: accentSoft'));
  });

  test('shared navigation uses blue selected states and flat dark surfaces', () {
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();
    final surfaces = File(
      'lib/widgets/premium_ui_v2.dart',
    ).readAsStringSync();
    final appPage = File('lib/widgets/app_page.dart').readAsStringSync();
    final surfacesV3 = File(
      'lib/widgets/premium_surfaces_v3.dart',
    ).readAsStringSync();
    final desktop = File(
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    ).readAsStringSync();

    expect(navigation, contains('color: scheme.surface'));
    expect(navigation, contains('scheme.primary.withValues(alpha: 0.11)'));
    expect(
      navigation,
      contains('color: selected ? scheme.primary : scheme.onSurfaceVariant'),
    );
    expect(navigation, isNot(contains('scheme.onPrimary')));

    expect(surfaces, contains('AppSurfaceBackdrop'));
    expect(appPage, contains('AppAdaptivePalette.darkBackground'));
    expect(surfacesV3, contains('Theme.of(context).brightness'));
    expect(desktop, contains('Theme.of(context).colorScheme'));
  });
}
