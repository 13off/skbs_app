import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../app/app_ui_tokens.dart';
import '../app/theme_controller.dart';
import '../navigation/platform_tab_override_scope.dart';
import 'liquid_glass.dart';

class AppPage extends StatelessWidget {
  static const double desktopBreakpoint = AppUi.desktopBreakpoint;

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? headerTrailing;
  final bool showBackButton;
  final bool suppressAutomaticBackButton;
  final VoidCallback? onBack;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Key? scrollKey;
  final double maxContentWidth;

  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.headerTrailing,
    this.showBackButton = false,
    this.suppressAutomaticBackButton = false,
    this.onBack,
    this.onRefresh,
    this.controller,
    this.physics,
    this.scrollKey,
    this.maxContentWidth = AppUi.pageContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    final canPop = navigator?.canPop() ?? false;
    final scopedTrailing = canPop
        ? null
        : PlatformTabOverrideScope.resolveRootHeaderTrailing(
            context,
          )?.call(context);
    final effectiveTrailing =
        title == 'Профиль' && !AppThemeController.featureEnabled
        ? null
        : headerTrailing ?? scopedTrailing;
    final effectiveShowBackButton =
        !suppressAutomaticBackButton && (showBackButton || canPop);
    final isDesktop = MediaQuery.sizeOf(context).width >= desktopBreakpoint;
    final visualStyle = LiquidGlassStyleScope.maybeOf(context);
    final pageHeaderGap = visualStyle?.compactPageLayout == true
        ? AppUi.gap16
        : AppUi.pageHeaderGap;
    final horizontalPadding = isDesktop
        ? AppUi.pageDesktopHorizontalPadding
        : AppUi.pageMobileHorizontalPadding;
    final topPadding = isDesktop
        ? AppUi.pageDesktopTopPadding
        : AppUi.pageMobileTopPadding;
    final effectiveMaxContentWidth = isDesktop
        ? double.infinity
        : maxContentWidth;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.35,
      decoration: TextDecoration.none,
    );

    final list = ListView(
      key: scrollKey,
      controller: controller,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        AppUi.pageBottomPadding,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: effectiveMaxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: title,
                  subtitle: subtitle ?? '',
                  trailing: effectiveTrailing,
                  showBackButton: effectiveShowBackButton,
                  onBack: onBack,
                ),
                SizedBox(height: pageHeaderGap),
                DefaultTextStyle.merge(
                  style: bodyStyle,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return AppSurfaceBackdrop(
      child: SafeArea(
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}

class AppLazyPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> leading;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final List<Widget> trailing;
  final Widget? headerTrailing;
  final bool showBackButton;
  final VoidCallback? onBack;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Key? scrollKey;
  final double cacheExtent;
  final double maxContentWidth;

  const AppLazyPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading = const <Widget>[],
    required this.itemCount,
    required this.itemBuilder,
    this.trailing = const <Widget>[],
    this.headerTrailing,
    this.showBackButton = false,
    this.onBack,
    this.controller,
    this.physics,
    this.scrollKey,
    this.cacheExtent = 600,
    this.maxContentWidth = AppUi.pageContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    final canPop = navigator?.canPop() ?? false;
    final scopedTrailing = canPop
        ? null
        : PlatformTabOverrideScope.resolveRootHeaderTrailing(
            context,
          )?.call(context);
    final effectiveTrailing =
        title == 'Профиль' && !AppThemeController.featureEnabled
        ? null
        : headerTrailing ?? scopedTrailing;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppPage.desktopBreakpoint;
    final visualStyle = LiquidGlassStyleScope.maybeOf(context);
    final pageHeaderGap = visualStyle?.compactPageLayout == true
        ? AppUi.gap16
        : AppUi.pageHeaderGap;
    final horizontalPadding = isDesktop
        ? AppUi.pageDesktopHorizontalPadding
        : AppUi.pageMobileHorizontalPadding;
    final topPadding = isDesktop
        ? AppUi.pageDesktopTopPadding
        : AppUi.pageMobileTopPadding;
    final effectiveMaxContentWidth = isDesktop
        ? double.infinity
        : maxContentWidth;
    final fixedLeadingCount = 2 + leading.length;
    final totalCount = fixedLeadingCount + itemCount + trailing.length;

    Widget constrain(Widget value) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxContentWidth),
        child: value,
      ),
    );

    final list = ListView.builder(
      // Flutter 3.44 deprecates this field before exposing its replacement.
      // ignore: deprecated_member_use
      cacheExtent: cacheExtent,
      key: scrollKey,
      controller: controller,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        AppUi.pageBottomPadding,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return constrain(
            AppPageHeader(
              title: title,
              subtitle: subtitle,
              trailing: effectiveTrailing,
              showBackButton: showBackButton || canPop,
              onBack: onBack,
            ),
          );
        }
        if (index == 1) {
          return SizedBox(height: pageHeaderGap);
        }
        final bodyIndex = index - 2;
        if (bodyIndex < leading.length) return constrain(leading[bodyIndex]);
        final listIndex = bodyIndex - leading.length;
        if (listIndex < itemCount) {
          return constrain(itemBuilder(context, listIndex));
        }
        return constrain(trailing[listIndex - itemCount]);
      },
    );

    return AppSurfaceBackdrop(child: SafeArea(child: list));
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
    final visualStyle = LiquidGlassStyleScope.maybeOf(context);
    final cleanSubtitle = visualStyle?.hidePageSubtitles == true
        ? ''
        : subtitle.trim();
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppUi.desktopBreakpoint;

    return LiquidGlassSurface(
      blur: !kIsWeb || isDesktop,
      blurSigma: isDesktop ? 18 : 14,
      radius: isDesktop ? 32 : 28,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 22 : 18,
        isDesktop ? 15 : 13,
        isDesktop ? 14 : 12,
        isDesktop ? 15 : 13,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppUi.pageHeaderMinHeight),
        child: Row(
          children: [
            if (showBackButton) ...[
              SizedBox.square(
                dimension: AppUi.pageHeaderActionSize,
                child: IconButton.filledTonal(
                  tooltip: 'Назад',
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(width: AppUi.gap12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: isDesktop ? 25 : 23,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.55,
                    ),
                  ),
                  if (cleanSubtitle.isNotEmpty) ...[
                    const SizedBox(height: AppUi.gap8),
                    Text(
                      cleanSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: isDesktop ? 13.5 : 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppUi.gap16),
              Align(
                alignment: Alignment.centerRight,
                child: IconButtonTheme(
                  data: IconButtonThemeData(
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(
                        AppUi.pageHeaderActionSize,
                      ),
                      padding: const EdgeInsets.all(13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppUi.controlRadius,
                        ),
                      ),
                    ),
                  ),
                  child: trailing!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppSurfaceBackdropScope extends InheritedWidget {
  const _AppSurfaceBackdropScope({required super.child});

  static bool maybeOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_AppSurfaceBackdropScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(_AppSurfaceBackdropScope oldWidget) => false;
}

class AppSurfaceBackdrop extends StatelessWidget {
  final Widget child;

  const AppSurfaceBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (_AppSurfaceBackdropScope.maybeOf(context)) return child;

    final dark = Theme.of(context).brightness == Brightness.dark;
    return _AppSurfaceBackdropScope(
      child: DecoratedBox(
        key: const ValueKey('app-surface-backdrop-layer'),
        decoration: BoxDecoration(
          color: dark
              ? AppAdaptivePalette.darkBackground
              : AppAdaptivePalette.background,
          // Dark mode uses the same graphite background as the global PWA frame.
          // This prevents a black rectangle from appearing inside the page margins.
          gradient: dark
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF5F7FA), Color(0xFFE9EDF2)],
                ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              bottom: -210,
              left: -145,
              child: IgnorePointer(
                child: Container(
                  width: 430,
                  height: 430,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppAdaptivePalette.telegramBlue.withValues(
                          alpha: dark ? 0.11 : 0.065,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
