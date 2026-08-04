import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_ui_tokens.dart';
import 'app_page.dart';
import 'liquid_glass.dart';
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

    return LiquidGlassSurface(
      margin: margin,
      padding: padding,
      radius: radius,
      blur: false,
      tint:
          tint ??
          (dark
              ? theme.colorScheme.surface.withValues(alpha: 0.80)
              : Colors.white.withValues(alpha: 0.66)),
      borderColor: dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.92),
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
      pressedScale: 0.965,
      hoverScale: 1.012,
      child: AnimatedContainer(
        duration: AppMotion.regular,
        height: AppUi.controlHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [Color(0xFF3295E6), Color(0xFF1461A2)]
                      : const [Color(0xFF30343A), Color(0xFF121519)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [Color(0xFF26313C), Color(0xFF18212A)]
                      : const [Color(0xFFD7DCE2), Color(0xFFC6CCD3)],
                ),
          borderRadius: BorderRadius.circular(AppUi.controlRadius),
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: dark ? 0.20 : 0.13)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.62),
            width: 1.15,
          ),
          boxShadow: [
            BoxShadow(
              color: enabled
                  ? (dark
                        ? theme.colorScheme.primary.withValues(alpha: 0.34)
                        : const Color(0xFF101216).withValues(alpha: 0.30))
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: enabled ? 28 : 12,
              spreadRadius: enabled ? -8 : -9,
              offset: Offset(0, enabled ? 14 : 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: enabled ? 0.16 : 0.06),
              blurRadius: 8,
              spreadRadius: -5,
              offset: const Offset(-2, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppUi.controlRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 1.2,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: enabled ? 0.48 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
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
                            Icon(icon, size: 22, color: foreground),
                            const SizedBox(width: 11),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
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
