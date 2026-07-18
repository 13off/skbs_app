import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

abstract final class AppDarkTheme {
  static const background = Color(0xFF0E1013);
  static const surface = Color(0xFF191C21);
  static const surfaceSoft = Color(0xFF22262C);
  static const border = Color(0xFF343941);
  static const textPrimary = Color(0xFFF1F3F5);
  static const textMuted = Color(0xFFA9AFB7);
  static const accent = Color(0xFFD7DBE0);

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(
      primary: accent,
      onPrimary: const Color(0xFF17191C),
      secondary: const Color(0xFFBFC5CC),
      onSecondary: const Color(0xFF17191C),
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textMuted,
      outline: border,
      outlineVariant: const Color(0xFF292D33),
      primaryContainer: const Color(0xFF30353C),
      onPrimaryContainer: textPrimary,
      secondaryContainer: const Color(0xFF292E34),
      onSecondaryContainer: textPrimary,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
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
        );

    final rounded24 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: border),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      pageTransitionsTheme: AppTheme.light.pageTransitionsTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.white.withValues(alpha: 0.08),
      appBarTheme: AppBarTheme(
        backgroundColor: background.withValues(alpha: 0.96),
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.38),
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: rounded24,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: 0.52),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceSoft,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0x99000000),
        showDragHandle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft.withValues(alpha: 0.94),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: textMuted.withValues(alpha: 0.78),
        ),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accent, width: 1.25),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textMuted,
      ),
      dividerColor: border,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceSoft,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF292D33),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFF17191C)
              : textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? accent : surfaceSoft;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(border),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: const Color(0xFF17191C),
          backgroundColor: accent,
          disabledForegroundColor: textMuted,
          disabledBackgroundColor: surfaceSoft,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: const Color(0xFF17191C),
          backgroundColor: accent,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surface.withValues(alpha: 0.72),
          side: const BorderSide(color: border),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(textPrimary),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.10);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.07);
            }
            return Colors.transparent;
          }),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF15181C).withValues(alpha: 0.97),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF353A42),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(color: textPrimary),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? textPrimary
                : textMuted,
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF15181C),
        selectedItemColor: textPrimary,
        unselectedItemColor: textMuted,
        elevation: 12,
      ),
    );
  }
}
