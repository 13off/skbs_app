import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import 'premium_ui_v2.dart' show PremiumBrandMark, PremiumDots;

class PremiumBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    if (dark) {
      return DecoratedBox(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -190,
              right: -150,
              child: IgnorePointer(
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.09),
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

    return const _LightPremiumBackdrop();
  }
}

class _LightPremiumBackdrop extends StatelessWidget {
  const _LightPremiumBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAF9F6), Color(0xFFE9E6DE)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -80,
            right: -55,
            child: _GlassDrop(size: 270, opacity: 0.72),
          ),
          const Positioned(
            left: -70,
            bottom: 70,
            child: _GlassDrop(size: 190, opacity: 0.46),
          ),
          const Positioned(
            right: 42,
            bottom: -58,
            child: _GlassDrop(size: 132, opacity: 0.36),
          ),
          child,
        ],
      ),
    );
  }
}

class PremiumLoadingScreen extends StatelessWidget {
  final String message;

  const PremiumLoadingScreen({
    super.key,
    this.message = 'Подготавливаем рабочее пространство',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: Container(
              width: 300,
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
              decoration: BoxDecoration(
                color: dark
                    ? theme.colorScheme.surface
                    : Colors.white.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(dark ? 24 : 36),
                border: Border.all(
                  color: dark
                      ? theme.colorScheme.outlineVariant
                      : Colors.white.withValues(alpha: 0.94),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.24 : 0.12),
                    blurRadius: dark ? 22 : 46,
                    spreadRadius: dark ? -10 : -14,
                    offset: Offset(0, dark ? 12 : 26),
                  ),
                  if (!dark)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.88),
                      blurRadius: 18,
                      spreadRadius: -10,
                      offset: const Offset(0, -6),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumBrandMark(size: 98, light: dark),
                  const SizedBox(height: 24),
                  Text(
                    'AppСтрой',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PremiumDots(color: dark ? theme.colorScheme.primary : textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassDrop extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlassDrop({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.36, -0.42),
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: opacity * 0.22),
              const Color(0xFFD5D0C4).withValues(alpha: opacity * 0.10),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: opacity * 0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: opacity * 0.10),
              blurRadius: size * 0.20,
              spreadRadius: -size * 0.08,
              offset: Offset(0, size * 0.10),
            ),
          ],
        ),
      ),
    );
  }
}
