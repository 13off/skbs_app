import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_ui_tokens.dart';
import 'app_page.dart';
import 'premium_ui_v2_legacy.dart' as legacy;

// Motion contract remains implemented in premium_ui_v2_legacy.dart:
// this.pressedScale = AppMotion.pressedScale
// this.hoverScale = AppMotion.hoverScale
// AppMotion.interactionCurve
// FocusableActionDetector
// void invokeAction()
export 'premium_ui_v2_legacy.dart'
    hide
        PremiumActionButton,
        PremiumBackdrop,
        PremiumLoadingScreen,
        PremiumWorkBackdrop,
        PremiumWorkCard;

class PremiumBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceBackdrop(child: child);
  }
}

class PremiumWorkBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumWorkBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceBackdrop(child: child);
  }
}

class PremiumWorkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color? tint;

  const PremiumWorkCard({
    super.key,
    required this.child,
    this.padding = AppUi.cardInsets,
    this.margin = EdgeInsets.zero,
    this.radius = AppUi.cardRadius,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? (tint ?? theme.colorScheme.surface) : tint,
        gradient: !dark && tint == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.91),
                  Colors.white.withValues(alpha: 0.72),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? theme.colorScheme.outlineVariant
              : Colors.white.withValues(alpha: 0.94),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.20 : 0.075),
            blurRadius: dark ? 18 : 28,
            spreadRadius: dark ? -10 : -12,
            offset: Offset(0, dark ? 9 : 16),
          ),
          if (!dark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.78),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: child,
    );
  }
}

class PremiumActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PremiumActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final enabled = onPressed != null && !isLoading;
    final foreground = enabled
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72);

    return legacy.PremiumPressable(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(AppUi.controlRadius),
      pressedScale: 0.982,
      child: AnimatedContainer(
        duration: AppMotion.regular,
        height: AppUi.controlHeight,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: dark
              ? (enabled
                    ? const Color(0xFF2278BF)
                    : const Color(0xFF1C2733))
              : null,
          gradient: dark
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A2D31), Color(0xFF17191C)],
                ),
          borderRadius: BorderRadius.circular(AppUi.controlRadius),
          border: Border.all(
            color: dark
                ? (enabled
                      ? theme.colorScheme.primary.withValues(alpha: 0.42)
                      : theme.colorScheme.outlineVariant)
                : Colors.white.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? theme.colorScheme.primary.withValues(alpha: enabled ? 0.16 : 0)
                  : const Color(0xFF15171A).withValues(alpha: 0.24),
              blurRadius: dark ? 18 : 24,
              spreadRadius: dark ? -10 : 0,
              offset: Offset(0, dark ? 8 : 12),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.regular,
          switchInCurve: AppMotion.enterCurve,
          switchOutCurve: AppMotion.exitCurve,
          child: isLoading
              ? Center(
                  key: const ValueKey('loading'),
                  child: legacy.PremiumDots(color: foreground),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: foreground),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class PremiumLoadingScreen extends StatelessWidget {
  final String message;

  const PremiumLoadingScreen({
    super.key,
    this.message = 'Собираем рабочее пространство',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  legacy.PremiumBrandMark(size: 92, light: dark),
                  const SizedBox(height: 28),
                  Text(
                    'AppСтрой',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  legacy.PremiumDots(color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
