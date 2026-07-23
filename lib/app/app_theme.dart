import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_ui_tokens.dart';

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
  static const regular = Duration(milliseconds: 180);
  static const hover = Duration(milliseconds: 180);
  static const page = Duration(milliseconds: 240);
  static const tab = Duration(milliseconds: 240);
  static const pressIn = Duration(milliseconds: 65);
  static const pressOut = Duration(milliseconds: 180);

  static const double hoverScale = 1.018;
  static const double pressedScale = 0.974;

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;
  static const Curve interactionCurve = Cubic(0.22, 1, 0.36, 1);
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

    ButtonLayerBuilder buttonSurface({
      required Color background,
      required Color hoveredBackground,
      required Color pressedBackground,
      required Color disabledBackground,
      Color? borderColor,
      Color? hoveredBorderColor,
      Color? pressedBorderColor,
      bool circular = false,
      bool elevated = false,
    }) {
      return (_, states, child) {
        final disabled = states.contains(WidgetState.disabled);
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        final focused = states.contains(WidgetState.focused);
        final activeHover = !disabled && !pressed && (hovered || focused);

        final color = disabled
            ? disabledBackground
            : pressed
            ? pressedBackground
            : activeHover
            ? hoveredBackground
            : background;
        final resolvedBorder = disabled
            ? borderColor?.withValues(alpha: 0.48)
            : pressed
            ? (pressedBorderColor ?? borderColor)
            : activeHover
            ? (hoveredBorderColor ?? borderColor)
            : borderColor;
        final scale = pressed
            ? AppMotion.pressedScale
            : activeHover
            ? AppMotion.hoverScale
            : 1.0;
        const radius = AppUi.controlRadius;

        return AnimatedScale(
          scale: scale,
          duration: pressed ? AppMotion.pressIn : AppMotion.hover,
          curve: pressed ? Curves.easeOut : AppMotion.interactionCurve,
          child: AnimatedContainer(
            duration: pressed ? AppMotion.pressIn : AppMotion.regular,
            curve: AppMotion.interactionCurve,
            decoration: BoxDecoration(
              color: color,
              shape: circular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circular ? null : BorderRadius.circular(radius),
              border: resolvedBorder == null
                  ? null
                  : Border.all(color: resolvedBorder),
              boxShadow: !elevated || disabled
                  ? const <BoxShadow>[]
                  : [
                      BoxShadow(
                        color: AppColors.accent.withValues(
                          alpha: pressed
                              ? 0.07
                              : activeHover
                              ? 0.17
                              : 0.10,
                        ),
                        blurRadius: pressed
                            ? 8
                            : activeHover
                            ? 22
                            : 12,
                        spreadRadius: activeHover ? -4 : -6,
                        offset: Offset(
                          0,
                          pressed
                              ? 2
                              : activeHover
                              ? 10
                              : 5,
                        ),
                      ),
                    ],
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      };
    }

    final filledButtonStyle = ButtonStyle(
      animationDuration: AppMotion.regular,
      minimumSize: const WidgetStatePropertyAll(Size(0, AppUi.controlHeight)),
      tapTargetSize: MaterialTapTargetSize.padded,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white.withValues(alpha: 0.68);
        }
        return Colors.white;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppUi.controlRadius)),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      backgroundBuilder: buttonSurface(
        background: AppColors.accent,
        hoveredBackground: const Color(0xFF30343A),
        pressedBackground: const Color(0xFF111316),
        disabledBackground: AppColors.accent.withValues(alpha: 0.38),
        elevated: true,
      ),
    );

    final outlinedButtonStyle = ButtonStyle(
      animationDuration: AppMotion.regular,
      minimumSize: const WidgetStatePropertyAll(Size(0, AppUi.controlHeight)),
      tapTargetSize: MaterialTapTargetSize.padded,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textMuted.withValues(alpha: 0.55);
        }
        return AppColors.textPrimary;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppUi.controlRadius)),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      backgroundBuilder: buttonSurface(
        background: Colors.white.withValues(alpha: 0.76),
        hoveredBackground: Colors.white,
        pressedBackground: AppColors.accentSoft,
        disabledBackground: Colors.white.withValues(alpha: 0.42),
        borderColor: AppColors.border,
        hoveredBorderColor: AppColors.accent.withValues(alpha: 0.28),
        pressedBorderColor: AppColors.accent.withValues(alpha: 0.44),
      ),
    );

    final textButtonStyle = ButtonStyle(
      animationDuration: AppMotion.regular,
      minimumSize: const WidgetStatePropertyAll(Size(0, AppUi.compactControlHeight)),
      tapTargetSize: MaterialTapTargetSize.padded,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textMuted.withValues(alpha: 0.50);
        }
        return AppColors.textPrimary;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppUi.controlRadius)),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      backgroundBuilder: buttonSurface(
        background: Colors.transparent,
        hoveredBackground: AppColors.accent.withValues(alpha: 0.055),
        pressedBackground: AppColors.accent.withValues(alpha: 0.085),
        disabledBackground: Colors.transparent,
      ),
    );

    final iconButtonStyle = ButtonStyle(
      animationDuration: AppMotion.regular,
      minimumSize: const WidgetStatePropertyAll(Size.square(AppUi.controlHeight)),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textMuted.withValues(alpha: 0.48);
        }
        return AppColors.textPrimary;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: const WidgetStatePropertyAll(CircleBorder()),
      backgroundBuilder: buttonSurface(
        background: Colors.transparent,
        hoveredBackground: Colors.white,
        pressedBackground: AppColors.accentSoft,
        disabledBackground: Colors.transparent,
        circular: true,
        elevated: true,
      ),
    );

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
          borderRadius: BorderRadius.circular(AppUi.cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
      textButtonTheme: TextButtonThemeData(style: textButtonStyle),
      iconButtonTheme: IconButtonThemeData(style: iconButtonStyle),
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
          borderRadius: BorderRadius.circular(AppUi.controlRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.controlRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.controlRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.25),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.controlRadius),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppUi.controlRadius)),
      ),
      dividerColor: AppColors.border,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.accentSoft,
      ),
    );
  }
}
