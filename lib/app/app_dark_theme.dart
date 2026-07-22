import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_adaptive_palette.dart';
import 'app_theme.dart';

abstract final class AppDarkTheme {
  static const background = AppAdaptivePalette.darkBackground;
  static const surface = AppAdaptivePalette.darkSurface;
  static const surfaceElevated = AppAdaptivePalette.darkSurfaceElevated;
  static const surfaceSoft = AppAdaptivePalette.darkSurfaceSoft;
  static const inputSurface = AppAdaptivePalette.darkInputSurface;
  static const border = AppAdaptivePalette.darkBorder;
  static const textPrimary = AppAdaptivePalette.darkTextPrimary;
  static const textMuted = AppAdaptivePalette.darkTextMuted;
  static const textFaint = AppAdaptivePalette.darkTextFaint;
  static const accent = AppAdaptivePalette.telegramBlue;
  static const accentStrong = AppAdaptivePalette.telegramBlueStrong;
  static const accentSoft = AppAdaptivePalette.darkAccentSoft;
  static const success = AppAdaptivePalette.darkSuccess;
  static const warning = AppAdaptivePalette.darkWarning;
  static const danger = AppAdaptivePalette.darkDanger;

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accentSoft,
      onPrimaryContainer: const Color(0xFFD7ECFF),
      secondary: const Color(0xFF64B5F6),
      onSecondary: const Color(0xFF07131E),
      secondaryContainer: const Color(0xFF1D3345),
      onSecondaryContainer: const Color(0xFFD7EAF9),
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textMuted,
      outline: border,
      outlineVariant: const Color(0xFF22303D),
      error: danger,
      onError: Colors.white,
      errorContainer: const Color(0xFF4A2530),
      onErrorContainer: const Color(0xFFFFD9DF),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
    );

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme)
        .apply(bodyColor: textPrimary, displayColor: textPrimary)
        .copyWith(
          displayLarge: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            color: textPrimary,
          ),
          displayMedium: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            color: textPrimary,
          ),
          headlineLarge: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: textPrimary,
          ),
          headlineMedium: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: textPrimary,
          ),
          titleLarge: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
            color: textPrimary,
          ),
          titleMedium: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          labelLarge: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
          labelMedium: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: textMuted,
          ),
          bodyLarge: GoogleFonts.manrope(
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: textPrimary,
          ),
          bodyMedium: GoogleFonts.manrope(
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: textPrimary,
          ),
          bodySmall: GoogleFonts.manrope(
            fontWeight: FontWeight.w500,
            height: 1.3,
            color: textMuted,
          ),
        );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: border),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      pageTransitionsTheme: AppTheme.light.pageTransitionsTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: accent.withValues(alpha: 0.06),
      focusColor: accent.withValues(alpha: 0.12),
      disabledColor: AppAdaptivePalette.darkDisabledText,
      iconTheme: const IconThemeData(color: textMuted),
      primaryIconTheme: const IconThemeData(color: textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
        iconTheme: const IconThemeData(color: textPrimary),
        actionsIconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.22),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.42),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0xB3000000),
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputSurface,
        labelStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textFaint),
        helperStyle: textTheme.bodySmall?.copyWith(color: textMuted),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF263442)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textMuted,
        selectedColor: accent,
        selectedTileColor: AppAdaptivePalette.darkSelectedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerColor: border,
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceSoft,
        circularTrackColor: surfaceSoft,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppAdaptivePalette.darkDisabledSurface;
          }
          return states.contains(WidgetState.selected) ? accent : surfaceSoft;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: textMuted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? accent : textMuted;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,
        selectedColor: accentSoft,
        disabledColor: AppAdaptivePalette.darkDisabledSurface,
        checkmarkColor: accent,
        labelStyle: textTheme.labelMedium?.copyWith(color: textPrimary),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: textPrimary),
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: accentStrong,
          disabledForegroundColor: AppAdaptivePalette.darkDisabledText,
          disabledBackgroundColor: AppAdaptivePalette.darkDisabledSurface,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: accentStrong,
          disabledForegroundColor: AppAdaptivePalette.darkDisabledText,
          disabledBackgroundColor: AppAdaptivePalette.darkDisabledSurface,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surface,
          disabledForegroundColor: AppAdaptivePalette.darkDisabledText,
          side: const BorderSide(color: border),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          disabledForegroundColor: AppAdaptivePalette.darkDisabledText,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppAdaptivePalette.darkDisabledText;
            }
            return textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return accent.withValues(alpha: 0.16);
            }
            if (states.contains(WidgetState.hovered)) {
              return accent.withValues(alpha: 0.10);
            }
            return Colors.transparent;
          }),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        foregroundColor: Colors.white,
        backgroundColor: accentStrong,
        splashColor: accent,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentSoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected) ? accent : textMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : textMuted,
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: textPrimary),
      ),
    );
  }
}
