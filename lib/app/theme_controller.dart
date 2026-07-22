import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_platform_sync.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const bool featureEnabled = true;
  static const String _preferenceKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(_preferenceKey);
      _themeMode = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      _themeMode = ThemeMode.light;
    }

    await AppThemePlatformSync.apply(isDark: isDark);
  }

  Future<void> setDark(bool value) async {
    final next = value ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == next) return;

    _themeMode = next;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_preferenceKey, value ? 'dark' : 'light');
    } catch (_) {
      // Тема уже применена в текущем запуске; сбой хранилища не блокирует UI.
    }

    await AppThemePlatformSync.apply(isDark: value);
  }

  Future<void> toggle() => setDark(!isDark);
}
