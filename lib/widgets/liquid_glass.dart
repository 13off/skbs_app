import 'dart:ui';

import 'package:flutter/material.dart';

/// Локальная настройка стеклянного визуального языка.
///
/// По умолчанию ничего не меняет. Рабочие контуры могут усилить глубину,
/// унифицировать радиусы карточек и уплотнить страницы, не затрагивая остальное
/// приложение.
class LiquidGlassStyleScope extends InheritedWidget {
  final double depth;
  final double? cardRadius;
  final bool hidePageSubtitles;
  final bool compactPageLayout;

  const LiquidGlassStyleScope({
    super.key,
    required super.child,
    this.depth = 1,
    this.cardRadius,
    this.hidePageSubtitles = false,
    this.compactPageLayout = false,
  }) : assert(depth >= 0.8 && depth <= 1.6);

  static LiquidGlassStyleScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LiquidGlassStyleScope>();
  }

  @override
  bool updateShouldNotify(LiquidGlassStyleScope oldWidget) {
    return depth != oldWidget.depth ||
        cardRadius != oldWidget.cardRadius ||
        hidePageSubtitles != oldWidget.hidePageSubtitles ||
        compactPageLayout != oldWidget.compactPageLayout;
  }
}

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
  final Gradient? gradient;
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
    this.gradient,
    this.borderColor,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final style = LiquidGlassStyleScope.maybeOf(context);
    final depth = style?.depth ?? 1.0;
    final depthDelta = depth - 1.0;
    final shadowFactor = 1.0 + depthDelta * 0.85;
    final geometryFactor = 1.0 + depthDelta * 0.55;
    final highlightFactor = 1.0 + depthDelta * 0.45;

    double scaledAlpha(double value, double factor, {double max = 1}) {
      return (value * factor).clamp(0.0, max).toDouble();
    }

    final resolvedTint =
        tint ??
        (dark
            ? scheme.surface.withValues(alpha: 0.74)
            : Colors.white.withValues(alpha: 0.58));
    final resolvedGradient =
        gradient ??
        LinearGradient(
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
        );
    final resolvedBorder =
        borderColor ??
        (dark
            ? Colors.white.withValues(
                alpha: scaledAlpha(0.13, highlightFactor, max: 0.22),
              )
            : Colors.white.withValues(
                alpha: scaledAlpha(0.90, highlightFactor, max: 0.98),
              ));
    final borderRadius = BorderRadius.circular(radius);
    final extraSpecularAlpha = depthDelta <= 0
        ? 0.0
        : (depthDelta * (dark ? 0.24 : 0.52)).clamp(0.0, 0.20).toDouble();

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedTint,
        gradient: resolvedGradient,
        borderRadius: borderRadius,
        border: Border.all(
          color: resolvedBorder,
          width: 1.15 * (1.0 + depthDelta * 0.20),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: scaledAlpha(
                      dark ? 0.34 : 0.13,
                      shadowFactor,
                      max: dark ? 0.48 : 0.22,
                    ),
                  ),
                  blurRadius: (dark ? 34 : 40) * geometryFactor,
                  spreadRadius: -15,
                  offset: Offset(0, 18 * geometryFactor),
                ),
                BoxShadow(
                  color: scheme.primary.withValues(
                    alpha: scaledAlpha(
                      dark ? 0.075 : 0.035,
                      shadowFactor,
                      max: dark ? 0.12 : 0.07,
                    ),
                  ),
                  blurRadius: 24 * geometryFactor,
                  spreadRadius: -16,
                  offset: Offset(0, 10 * geometryFactor),
                ),
                BoxShadow(
                  color: Colors.white.withValues(
                    alpha: scaledAlpha(
                      dark ? 0.055 : 0.74,
                      highlightFactor,
                      max: dark ? 0.09 : 0.92,
                    ),
                  ),
                  blurRadius: 12 * geometryFactor,
                  spreadRadius: -7,
                  offset: Offset(-3, -5 * geometryFactor),
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
                      Colors.white.withValues(
                        alpha: scaledAlpha(
                          dark ? 0.085 : 0.44,
                          highlightFactor,
                          max: dark ? 0.14 : 0.62,
                        ),
                      ),
                      Colors.white.withValues(
                        alpha: scaledAlpha(
                          dark ? 0.018 : 0.08,
                          highlightFactor,
                          max: dark ? 0.04 : 0.14,
                        ),
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.36, 1],
                  ),
                ),
              ),
            ),
          ),
          if (extraSpecularAlpha > 0)
            Positioned(
              left: radius * 0.12,
              top: -radius * 0.78,
              child: IgnorePointer(
                child: Container(
                  width: radius * 4.3,
                  height: radius * 2.25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.55, -0.55),
                      radius: 1,
                      colors: [
                        Colors.white.withValues(alpha: extraSpecularAlpha),
                        Colors.white.withValues(alpha: extraSpecularAlpha * 0.22),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.44, 1],
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
                      Colors.white.withValues(
                        alpha: scaledAlpha(
                          dark ? 0.22 : 0.92,
                          highlightFactor,
                          max: dark ? 0.34 : 1,
                        ),
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (extraSpecularAlpha > 0)
            Positioned(
              left: radius * 0.72,
              right: radius * 0.72,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(
                          alpha: extraSpecularAlpha * (dark ? 0.42 : 0.75),
                        ),
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
