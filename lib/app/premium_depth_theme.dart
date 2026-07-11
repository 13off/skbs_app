import 'package:flutter/material.dart';

import 'app_theme.dart';

abstract final class PremiumDepthTheme {
  static ThemeData apply(ThemeData base) {
    const primaryText = Color(0xFF1F2328);
    const mutedText = Color(0xFF6B7075);
    final textTheme = base.textTheme.apply(
      bodyColor: primaryText,
      displayColor: primaryText,
    );

    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF2F0EB),
      canvasColor: const Color(0xFFF2F0EB),
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.light,
        onSurface: primaryText,
        onSurfaceVariant: mutedText,
        onPrimaryContainer: primaryText,
        onSecondaryContainer: primaryText,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryText,
        selectionColor: Color(0x334A6F98),
        selectionHandleColor: Color(0xFF4A6F98),
      ),
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
        foregroundColor: primaryText,
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
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: primaryText,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: primaryText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.95)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium?.copyWith(color: primaryText),
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
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.88),
        labelStyle: const TextStyle(color: mutedText),
        floatingLabelStyle: const TextStyle(
          color: primaryText,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: Color(0xFF92979C)),
        prefixIconColor: mutedText,
        suffixIconColor: mutedText,
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
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyLarge?.copyWith(color: primaryText),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.88),
          labelStyle: const TextStyle(color: mutedText),
          hintStyle: const TextStyle(color: Color(0xFF92979C)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: primaryText,
        iconColor: mutedText,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
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
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(primaryText),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(primaryText),
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
          foregroundColor: const WidgetStatePropertyAll(primaryText),
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
    );
  }
}
