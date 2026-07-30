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
        : PlatformTabOverrideScope.resolveRootHeaderTrailing(context)?.call(
            context,
          );
    final effectiveTrailing =
        title == 'Профиль' && !AppThemeController.featureEnabled
        ? null
        : headerTrailing ?? scopedTrailing;
    final effectiveShowBackButton = showBackButton || canPop;
    final isDesktop = MediaQuery.sizeOf(context).width >= desktopBreakpoint;
    final horizontalPadding = isDesktop
        ? AppUi.pageDesktopHorizontalPadding
        : AppUi.pageMobileHorizontalPadding;
    final topPadding = isDesktop
        ? AppUi.pageDesktopTopPadding
        : AppUi.pageMobileTopPadding;
    final effectiveMaxContentWidth = isDesktop && title == 'Кандидаты'
        ? double.infinity
        : maxContentWidth;

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
                const SizedBox(height: AppUi.pageHeaderGap),
                child,
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
        : PlatformTabOverrideScope.resolveRootHeaderTrailing(context)?.call(
            context,
          );
    final effectiveTrailing =
        title == 'Профиль' && !AppThemeController.featureEnabled
        ? null
        : headerTrailing ?? scopedTrailing;
    final effectiveShowBackButton = showBackButton || canPop;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppPage.desktopBreakpoint;
    final horizontalPadding = isDesktop
        ? AppUi.pageDesktopHorizontalPadding
        : AppUi.pageMobileHorizontalPadding;
    final topPadding = isDesktop
        ? AppUi.pageDesktopTopPadding
        : AppUi.pageMobileTopPadding;
    final fixedLeadingCount = 2 + leading.length;
    final totalCount = fixedLeadingCount + itemCount + trailing.length;

    Widget constrain(Widget child) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );
    }

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
              showBackButton: effectiveShowBackButton,
              onBack: onBack,
            ),
          );
        }
        if (index == 1) return const SizedBox(height: AppUi.pageHeaderGap);
        final localIndex = index - 2;
        if (localIndex < leading.length) {
          return constrain(leading[localIndex]);
        }
        final lazyIndex = localIndex - leading.length;
        if (lazyIndex < itemCount) {
          return constrain(itemBuilder(context, lazyIndex));
        }
        return constrain(trailing[lazyIndex - itemCount]);
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
    return AppLiquidPanel(
      radius: AppUi.pageHeaderRadius,
      blurSigma: 8,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              tooltip: 'Назад',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppAdaptivePalette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppAdaptivePalette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
