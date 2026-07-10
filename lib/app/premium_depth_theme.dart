import 'package:flutter/material.dart';

import 'app_theme.dart';

abstract final class PremiumDepthTheme {
  static ThemeData apply(ThemeData base) {
    final textTheme = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF2F0EB),
      canvasColor: const Color(0xFFF2F0EB),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.86),
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF1B1D21).withValues(alpha: 0.10),
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.92),
            width: 1,
          ),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: const Color(0xFFF5F3EE).withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF191B1F).withValues(alpha: 0.08),
        elevation: 0,
        scrolledUnderElevation: 1.5,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: const Color(0xFF181A1D).withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.95)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: const Color(0xFF17191C).withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        modalBackgroundColor: Colors.white.withValues(alpha: 0.96),
        elevation: 18,
        shadowColor: const Color(0xFF17191C).withValues(alpha: 0.16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: Colors.white.withValues(alpha: 0.82),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.96),
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          shadowColor: WidgetStatePropertyAll(
            AppColors.accent.withValues(alpha: 0.18),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 3;
            return 1.5;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.72);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.88);
            }
            return Colors.white.withValues(alpha: 0.58);
          }),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: states.contains(WidgetState.focused)
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.94),
            );
          }),
          shadowColor: WidgetStatePropertyAll(
            const Color(0xFF17191C).withValues(alpha: 0.08),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 2;
            return 0.5;
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: base.iconButtonTheme.style?.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.accent.withValues(alpha: 0.09);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.90);
            }
            return Colors.transparent;
          }),
          shadowColor: WidgetStatePropertyAll(
            const Color(0xFF17191C).withValues(alpha: 0.07),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return 2;
            return 0;
          }),
        ),
      ),
      textTheme: textTheme,
    );
  }
}
