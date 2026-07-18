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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF15181C), Color(0xFF090B0E)]
              : const [Color(0xFFF9F8F5), Color(0xFFECEAE4)],
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF15181C), Color(0xFF090B0E)]
              : const [Color(0xFFFAF9F6), Color(0xFFECE9E2)],
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
                    colors: dark
                        ? [
                            const Color(0xFF4D5661).withValues(alpha: 0.24),
                            Colors.transparent,
                          ]
                        : [
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
    final surface = theme.colorScheme.surface;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: tint,
        gradient: tint == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        surface.withValues(alpha: 0.97),
                        const Color(0xFF16191D).withValues(alpha: 0.94),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.91),
                        Colors.white.withValues(alpha: 0.72),
                      ],
              )
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? theme.colorScheme.outline.withValues(alpha: 0.86)
              : Colors.white.withValues(alpha: 0.94),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.34 : 0.075),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: dark ? 0.025 : 0.78),
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
                  legacy.PremiumDots(color: theme.colorScheme.onSurface),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
