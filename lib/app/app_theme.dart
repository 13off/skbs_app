import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFFF5F4F1);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xFFF0EFEB);
  static const textPrimary = Color(0xFF202327);
  static const textMuted = Color(0xFF6D7176);
  static const border = Color(0xFFE2E1DC);
  static const accent = Color(0xFF25282C);
  static const accentSoft = Color(0xFFE8E7E3);
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 110);
  static const regular = Duration(milliseconds: 190);
  static const page = Duration(milliseconds: 260);
  static const tab = Duration(milliseconds: 220);
  static const pressIn = Duration(milliseconds: 55);
  static const pressOut = Duration(milliseconds: 150);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;
  static const Curve springCurve = Curves.easeOutCubic;
}

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (animationsDisabled || route.isFirst) {
      return child;
    }

    final primary = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enterCurve,
      reverseCurve: AppMotion.exitCurve,
    );
    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.enterCurve,
      reverseCurve: AppMotion.exitCurve,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(primary),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.075, 0),
        ).animate(secondary),
        child: child,
      ),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light {
    const pageTransitionsBuilder = _AppPageTransitionsBuilder();
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
    );
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
      ),
      displayMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.35,
      ),
      titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      labelLarge: GoogleFonts.manrope(fontWeight: FontWeight.w800),
      bodyLarge: GoogleFonts.manrope(fontWeight: FontWeight.w500, height: 1.35),
      bodyMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
    );

    WidgetStateProperty<Color?> subtleOverlay() {
      return WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withValues(alpha: 0.06);
        }
        return Colors.transparent;
      });
    }

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: AppColors.accent.withValues(alpha: 0.06),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: pageTransitionsBuilder,
          TargetPlatform.iOS: pageTransitionsBuilder,
          TargetPlatform.macOS: pageTransitionsBuilder,
          TargetPlatform.windows: pageTransitionsBuilder,
          TargetPlatform.linux: pageTransitionsBuilder,
          TargetPlatform.fuchsia: pageTransitionsBuilder,
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          animationDuration: AppMotion.regular,
          minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.accent.withValues(alpha: 0.38);
            }
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF111316);
            }
            return AppColors.accent;
          }),
          overlayColor: subtleOverlay(),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 5;
            return 2;
          }),
          shadowColor: WidgetStatePropertyAll(
            AppColors.accent.withValues(alpha: 0.24),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          shape: WidgetStateProperty.resolveWith((states) {
            final radius = states.contains(WidgetState.pressed) ? 15.0 : 18.0;
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            );
          }),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          animationDuration: AppMotion.regular,
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.accent.withValues(alpha: 0.07);
            }
            return Colors.transparent;
          }),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            final color = states.contains(WidgetState.focused)
                ? AppColors.accent
                : AppColors.border;
            return BorderSide(color: color);
          }),
          shape: WidgetStateProperty.resolveWith((states) {
            final radius = states.contains(WidgetState.pressed) ? 15.0 : 18.0;
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            );
          }),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          animationDuration: AppMotion.regular,
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.accent.withValues(alpha: 0.06);
            }
            return Colors.transparent;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: AppMotion.fast,
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
          foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.accent.withValues(alpha: 0.10);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white;
            }
            return Colors.transparent;
          }),
          shadowColor: WidgetStatePropertyAll(
            AppColors.accent.withValues(alpha: 0.18),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return 7;
            if (states.contains(WidgetState.pressed)) return 1;
            return 0;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(CircleBorder()),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.84),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted.withValues(alpha: 0.75),
        ),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.25),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFB55252)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        modalBarrierColor: Color(0x520D0F12),
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF23262A),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: AppColors.border,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.accentSoft,
      ),
    );
  }
}
