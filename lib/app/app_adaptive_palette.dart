import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'theme_controller.dart';

/// Единая адаптивная палитра для экранов, которые используют собственные
/// поверхности поверх общего ThemeData. Тёмная ветка выполнена в спокойной
/// сине-графитовой стилистике мессенджера, без чистого чёрного и белых карточек.
abstract final class AppAdaptivePalette {
  static bool get isDark => AppThemeController.instance.isDark;

  static const darkBackground = Color(0xFF0E1621);
  static const darkSurface = Color(0xFF17212B);
  static const darkSurfaceElevated = Color(0xFF1F2C3A);
  static const darkSurfaceSoft = Color(0xFF22303D);
  static const darkInputSurface = Color(0xFF242F3D);
  static const darkBorder = Color(0xFF2B3A49);
  static const darkTextPrimary = Color(0xFFF5F7FA);
  static const darkTextMuted = Color(0xFFA5B3C1);
  static const darkTextFaint = Color(0xFF708499);
  static const telegramBlue = Color(0xFF3390EC);
  static const telegramBlueStrong = Color(0xFF2278BF);
  static const darkAccentSoft = Color(0xFF203A52);
  static const darkSelectedSurface = Color(0xFF1D3448);
  static const darkDisabledSurface = Color(0xFF22303D);
  static const darkDisabledText = Color(0xFF8DA1B4);
  static const darkSuccess = Color(0xFF4FAE6E);
  static const darkWarning = Color(0xFFF0A44B);
  static const darkDanger = Color(0xFFE05D6F);

  static Color get background => isDark ? darkBackground : AppColors.background;

  static Color get surface => isDark ? darkSurface : AppColors.surface;

  static Color get surfaceElevated =>
      isDark ? darkSurfaceElevated : Colors.white;

  static Color get surfaceSoft =>
      isDark ? darkSurfaceSoft : AppColors.surfaceSoft;

  static Color get inputSurface => isDark ? darkInputSurface : Colors.white;

  static Color get navigationSurface =>
      isDark ? darkSurface : AppColors.surface;

  static Color get selectedSurface =>
      isDark ? darkSelectedSurface : AppColors.accentSoft;

  static Color get textPrimary =>
      isDark ? darkTextPrimary : AppColors.textPrimary;

  static Color get textMuted => isDark ? darkTextMuted : AppColors.textMuted;

  static Color get textFaint =>
      isDark ? darkTextFaint : const Color(0xFF8F9499);

  static Color get border => isDark ? darkBorder : AppColors.border;

  static Color get accent => isDark ? telegramBlue : AppColors.accent;

  static Color get accentStrong =>
      isDark ? telegramBlueStrong : AppColors.accent;

  static Color get onAccent => Colors.white;

  static Color get accentSoft => isDark ? darkAccentSoft : AppColors.accentSoft;

  static Color get disabledSurface =>
      isDark ? darkDisabledSurface : const Color(0xFFE2E3E4);

  static Color get disabledText =>
      isDark ? darkDisabledText : const Color(0xFF8F9499);

  static Color get success => isDark ? darkSuccess : const Color(0xFF22C55E);

  static Color get warning => isDark ? darkWarning : const Color(0xFFF59E0B);

  static Color get danger => isDark ? darkDanger : const Color(0xFFDC2626);

  static Color get info => accent;

  static Color get modalBarrier =>
      isDark ? const Color(0xB3000000) : const Color(0x66000000);
}
