import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1F2328);
  static const textMuted = Color(0xFF6B7075);
  static const border = Color(0xFFE4E7EB);
  static const accent = Color(0xFF8F9499);
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const regular = Duration(milliseconds: 240);
  static const page = Duration(milliseconds: 260);
  static const tab = Duration(milliseconds: 260);

  static const Curve enterCurve = Curves.easeOutCubic;

  /// Выход должен начинаться сразу, иначе после нажатия «Назад» первые
  /// миллисекунды почти ничего не менялось и кнопка казалась нерабочей.
  static const Curve exitCurve = Curves.easeOutCubic;

  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;
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

    final isPopping = animation.status == AnimationStatus.reverse;
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enterCurve,
      reverseCurve: AppMotion.exitCurve,
    );

    final slideAnimation = Tween<Offset>(
      begin: Offset(isPopping ? 0.055 : 0.035, 0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    return RepaintBoundary(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(curvedAnimation),
        child: SlideTransition(position: slideAnimation, child: child),
      ),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light {
    const pageTransitionsBuilder = _AppPageTransitionsBuilder();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
      ),
      fontFamily: 'Inter',
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
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
