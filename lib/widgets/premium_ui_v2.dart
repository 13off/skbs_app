import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import 'premium_ui_v2_legacy.dart' as legacy;

// Motion contract remains implemented in premium_ui_v2_legacy.dart:
// this.pressedScale = AppMotion.pressedScale
// this.hoverScale = AppMotion.hoverScale
// AppMotion.interactionCurve
// FocusableActionDetector
// void invokeAction()
export 'premium_ui_v2_legacy.dart'
    hide PremiumBackdrop, PremiumLoadingScreen, PremiumWorkBackdrop, PremiumWorkCard;

class PremiumBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: dark
          ? BoxDecoration(color: theme.scaffoldBackgroundColor)
          : const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF9F8F5), Color(0xFFECEAE4)],
              ),
            ),
      child: child,
    );
  }
}

class PremiumWorkBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumWorkBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    if (!dark) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFAF9F6), Color(0xFFECE9E2)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -140,
              right: -100,
              child: IgnorePointer(
                child: Container(
                  width: 330,
                  height: 330,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.94),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -180,
            right: -140,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.10),
                      theme.colorScheme.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
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
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.radius = 26,
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
