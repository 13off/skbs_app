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
            ? scheme.surface.withValues(alpha: 0.76)
            : Colors.white.withValues(alpha: 0.56));
    final resolvedBorder = borderColor ??
        (dark
            ? Colors.white.withValues(alpha: 0.11)
            : Colors.white.withValues(alpha: 0.78));
    final borderRadius = BorderRadius.circular(radius);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedTint,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  scheme.surfaceContainerHighest.withValues(alpha: 0.78),
                  scheme.surface.withValues(alpha: 0.66),
                ]
              : [
                  Colors.white.withValues(alpha: 0.78),
                  Colors.white.withValues(alpha: 0.42),
                ],
          stops: const [0, 1],
        ),
        borderRadius: borderRadius,
        border: Border.all(color: resolvedBorder, width: 1.05),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.24 : 0.10),
                  blurRadius: dark ? 24 : 32,
                  spreadRadius: -12,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: dark ? 0.035 : 0.55),
                  blurRadius: 8,
                  spreadRadius: -5,
                  offset: const Offset(-2, -3),
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
                      Colors.white.withValues(alpha: dark ? 0.045 : 0.30),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                    stops: const [0, 0.38, 1],
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
