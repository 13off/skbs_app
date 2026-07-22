import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../app/theme_controller.dart';

class AppPage extends StatelessWidget {
  static const double desktopBreakpoint = 1050;

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerTrailing;
  final bool showBackButton;
  final VoidCallback? onBack;

  const AppPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTrailing =
        title == 'Профиль' && !AppThemeController.featureEnabled
        ? null
        : headerTrailing;
    final navigator = Navigator.maybeOf(context);
    final effectiveShowBackButton =
        showBackButton || (navigator?.canPop() ?? false);
    final isDesktop = MediaQuery.sizeOf(context).width >= desktopBreakpoint;
    final horizontalPadding = isDesktop ? 28.0 : 14.0;
    final topPadding = isDesktop ? 24.0 : 12.0;
    final maxContentWidth = isDesktop ? 1180.0 : 720.0;

    return _AppPageBackdrop(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            120,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPageHeader(
                      title: title,
                      subtitle: subtitle,
                      trailing: effectiveTrailing,
                      showBackButton: effectiveShowBackButton,
                      onBack: onBack,
                    ),
                    SizedBox(height: isDesktop ? 18 : 14),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool showBackButton;
  final VoidCallback? onBack;

  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = trailing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBackButton) ...[
          BackButton(
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          Flexible(fit: FlexFit.loose, child: action),
        ],
      ],
    );
  }
}

class _AppPageBackdrop extends StatelessWidget {
  final Widget child;

  const _AppPageBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  AppAdaptivePalette.darkBackground,
                  AppAdaptivePalette.darkSurface,
                ]
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
                            AppAdaptivePalette.telegramBlue.withValues(alpha: 0.12),
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
