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
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();

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

    expect(profile, contains('headerTrailing: buildThemeToggle()'));
    expect(profile, contains('Icons.dark_mode_rounded'));
    expect(profile, contains('Icons.light_mode_rounded'));
    expect(profile, contains('onPressed: controller.toggle'));
  });

  test('dark palette keeps primary text and actions readable', () {
    final theme = AppDarkTheme.theme;
    final scheme = theme.colorScheme;

    expect(theme.brightness, Brightness.dark);
    expect(contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(7));
    expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(7));
    expect(
      contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('shared navigation and desktop surfaces use the active theme', () {
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();
    final desktop = File(
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    ).readAsStringSync();

    expect(navigation, contains('final scheme = theme.colorScheme'));
    expect(navigation, contains('scheme.surface.withValues'));
    expect(navigation, contains('scheme.onPrimary'));
    expect(
      navigation,
      isNot(contains('color: Colors.white.withValues(alpha: 0.97)')),
    );

    expect(desktop, contains("import '../../../app/theme_controller.dart';"));
    expect(desktop, contains('AppThemeController.instance.isDark'));
    expect(desktop, contains('Theme.of(context).colorScheme.onSurface'));
  });

  test('dark theme remains a presentation-only change', () {
    final changedSources = <String>[
      'lib/app/theme_controller.dart',
      'lib/widgets/professional_bottom_navigation.dart',
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    ];

    for (final path in changedSources) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')), reason: path);
      expect(source, isNot(contains('.insert(')), reason: path);
      expect(source, isNot(contains('.update(')), reason: path);
      expect(source, isNot(contains('.delete(')), reason: path);
    }
  });
}
