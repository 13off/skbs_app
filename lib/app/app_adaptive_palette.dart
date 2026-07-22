import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'theme_controller.dart';

/// Единая адаптивная палитра для экранов, которые ещё используют
/// собственные цвета поверх общего ThemeData.
abstract final class AppAdaptivePalette {
  static bool get isDark => AppThemeController.instance.isDark;

  static Color get background =>
      isDark ? const Color(0xFF0B0D10) : AppColors.background;

  static Color get surface =>
      isDark ? const Color(0xFF171A1F) : AppColors.surface;

  static Color get surfaceElevated =>
      isDark ? const Color(0xFF1D2127) : Colors.white;

  static Color get surfaceSoft =>
      isDark ? const Color(0xFF242932) : AppColors.surfaceSoft;

  static Color get inputSurface =>
      isDark ? const Color(0xFF1E2228) : Colors.white;

  static Color get textPrimary =>
      isDark ? const Color(0xFFF2F4F7) : AppColors.textPrimary;

  static Color get textMuted =>
      isDark ? const Color(0xFFB2B9C3) : AppColors.textMuted;

  static Color get textFaint =>
      isDark ? const Color(0xFF7F8894) : const Color(0xFF8F9499);

  static Color get border =>
      isDark ? const Color(0xFF353C46) : AppColors.border;

  static Color get accent =>
      isDark ? const Color(0xFFDDE2E8) : AppColors.accent;

  static Color get onAccent =>
      isDark ? const Color(0xFF181B20) : Colors.white;

  static Color get accentSoft =>
      isDark ? const Color(0xFF2B3139) : AppColors.accentSoft;

  static Color get disabledSurface =>
      isDark ? const Color(0xFF2A2F36) : const Color(0xFFE2E3E4);

  static Color get disabledText =>
      isDark ? const Color(0xFF7D8691) : const Color(0xFF8F9499);
}
