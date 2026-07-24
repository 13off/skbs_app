import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_platform_sync.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const bool featureEnabled = true;
  static const bool scaleFeatureEnabled = true;
  static const String _preferenceKey = 'app_theme_mode';
  static const String _scalePreferenceKey = 'app_ui_scale';
  static const double defaultUiScale = 0.90;
  static const List<double> uiScaleOptions = <double>[
    0.80,
    0.90,
    1.00,
    1.10,
    1.20,
  ];

  ThemeMode _themeMode = ThemeMode.light;
  double _uiScale = defaultUiScale;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  double get uiScale => _uiScale;
  int get uiScalePercent => (_uiScale * 100).round();

  double _normalizeUiScale(double value) {
    return uiScaleOptions.reduce(
      (current, option) =>
          (option - value).abs() < (current - value).abs()
          ? option
          : current,
    );
  }

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(_preferenceKey);
      _themeMode = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _uiScale = _normalizeUiScale(
        preferences.getDouble(_scalePreferenceKey) ?? defaultUiScale,
      );
    } catch (_) {
      _themeMode = ThemeMode.light;
      _uiScale = defaultUiScale;
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

  Future<void> setUiScale(double value) async {
    final next = _normalizeUiScale(value);
    if ((_uiScale - next).abs() < 0.001) return;

    _uiScale = next;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_scalePreferenceKey, next);
    } catch (_) {
      // Масштаб уже применён в текущем запуске; сбой хранилища не блокирует UI.
    }
  }

  Future<void> decreaseUiScale() {
    final currentIndex = uiScaleOptions.indexOf(_uiScale);
    final nextIndex = currentIndex <= 0 ? 0 : currentIndex - 1;
    return setUiScale(uiScaleOptions[nextIndex]);
  }

  Future<void> increaseUiScale() {
    final currentIndex = uiScaleOptions.indexOf(_uiScale);
    final nextIndex = currentIndex < 0
        ? uiScaleOptions.indexOf(defaultUiScale)
        : (currentIndex + 1).clamp(0, uiScaleOptions.length - 1);
    return setUiScale(uiScaleOptions[nextIndex]);
  }

  Future<void> resetUiScale() => setUiScale(defaultUiScale);

  Future<void> toggle() => setDark(!isDark);
}
