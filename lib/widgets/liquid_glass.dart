import 'dart:ui';

import 'package:flutter/material.dart';

/// Лёгкая стеклянная поверхность для единичных панелей.
///
/// Настоящее размытие включается только явно. Для длинных списков и повторяющихся
/// карточек используется тот же визуальный язык без BackdropFilter, чтобы Web/PWA
/// оставалась быстрой.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final bool blur;
  final double blurSigma;
  final Color? tint;
  final Color? borderColor;
  final bool elevated;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.radius = 28,
    this.blur = false,
    this.blurSigma = 16,
    this.tint,
    this.borderColor,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final resolvedTint = tint ??
        (dark
            ? scheme.surface.withValues(alpha: 0.74)
            : Colors.white.withValues(alpha: 0.58));
    final resolvedBorder = borderColor ??
        (dark
            ? Colors.white.withValues(alpha: 0.13)
            : Colors.white.withValues(alpha: 0.90));
    final borderRadius = BorderRadius.circular(radius);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedTint,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  scheme.surfaceContainerHighest.withValues(alpha: 0.84),
                  scheme.surface.withValues(alpha: 0.66),
                  const Color(0xFF11171E).withValues(alpha: 0.72),
                ]
              : [
                  Colors.white.withValues(alpha: 0.90),
                  Colors.white.withValues(alpha: 0.58),
                  const Color(0xFFE9EEF4).withValues(alpha: 0.58),
                ],
          stops: const [0, 0.55, 1],
        ),
        borderRadius: borderRadius,
        border: Border.all(color: resolvedBorder, width: 1.15),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.34 : 0.13),
                  blurRadius: dark ? 34 : 40,
                  spreadRadius: -15,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: scheme.primary.withValues(alpha: dark ? 0.075 : 0.035),
                  blurRadius: 24,
                  spreadRadius: -16,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: dark ? 0.055 : 0.74),
                  blurRadius: 12,
                  spreadRadius: -7,
                  offset: const Offset(-3, -5),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.085 : 0.44),
                      Colors.white.withValues(alpha: dark ? 0.018 : 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.36, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: radius * 0.55,
            right: radius * 0.55,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: dark ? 0.22 : 0.92),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    final clipped = ClipRRect(
      borderRadius: borderRadius,
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: surface,
            )
          : surface,
    );

    return RepaintBoundary(
      child: Padding(padding: margin, child: clipped),
    );
  }
}
