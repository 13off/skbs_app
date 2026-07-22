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

    expect(surfaces, contains('theme.scaffoldBackgroundColor'));
    expect(surfaces, contains('theme.colorScheme.outlineVariant'));
    expect(surfaces, contains('const Color(0xFF2278BF)'));
    expect(
      surfaces,
      isNot(contains("const [Color(0xFF15181C), Color(0xFF090B0E)]")),
    );
    expect(surfacesV3, contains('theme.colorScheme.primary.withValues(alpha: 0.09)'));

    expect(desktop, contains("import '../../../app/theme_controller.dart';"));
    expect(desktop, contains('AppThemeController.instance.isDark'));
    expect(desktop, contains('Theme.of(context).colorScheme.onSurface'));
  });

  test('dark theme remains a presentation-only change', () {
    final changedSources = <String>[
      'lib/app/app_adaptive_palette.dart',
      'lib/app/app_dark_theme.dart',
      'lib/app/theme_controller.dart',
      'lib/widgets/professional_bottom_navigation.dart',
      'lib/widgets/premium_surfaces_v3.dart',
      'lib/widgets/premium_ui_v2.dart',
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
