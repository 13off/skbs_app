import 'package:flutter/material.dart';

import '../app/app_ui_tokens.dart';
import 'app_page.dart';
import 'premium_ui_v2.dart' show PremiumBrandMark, PremiumDots;

class PremiumBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceBackdrop(child: child);
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
                borderRadius: BorderRadius.circular(AppUi.modalRadius),
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
