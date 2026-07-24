import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../app/app_ui_tokens.dart';
import '../app/theme_controller.dart';

class AppPage extends StatelessWidget {
  static const double desktopBreakpoint = AppUi.desktopBreakpoint;

  final String title;
  final String subtitle;
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
    required this.subtitle,
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
    final effectiveTrailing =
        title == 'Профиль' && !AppThemeController.featureEnabled
        ? null
        : headerTrailing;
    final navigator = Navigator.maybeOf(context);
    final effectiveShowBackButton =
        showBackButton || (navigator?.canPop() ?? false);
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
                  subtitle: subtitle,
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
    final effectiveTrailing =
        title == 'Профиль' && !AppThemeController.featureEnabled
        ? null
        : headerTrailing;
    final navigator = Navigator.maybeOf(context);
    final effectiveShowBackButton =
        showBackButton || (navigator?.canPop() ?? false);
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
      key: scrollKey,
      controller: controller,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      cacheExtent: cacheExtent,
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
        if (index == 1) {
          return const SizedBox(height: AppUi.pageHeaderGap);
        }

        final bodyIndex = index - 2;
        if (bodyIndex < leading.length) {
          return constrain(leading[bodyIndex]);
        }

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
    final action = trailing;
    final cleanSubtitle = subtitle.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppUi.pageHeaderMinHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBackButton) ...[
            SizedBox.square(
              dimension: AppUi.pageHeaderActionSize,
              child: BackButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: AppUi.gap8),
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
                    fontSize: 20,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: AppUi.gap4),
                SizedBox(
                  height: 18,
                  child: Text(
                    cleanSubtitle.isEmpty ? ' ' : cleanSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppUi.gap12),
            Flexible(
              fit: FlexFit.loose,
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(
                      AppUi.pageHeaderActionSize,
                    ),
                    maximumSize: const Size.square(
                      AppUi.pageHeaderActionSize,
                    ),
                    padding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUi.controlRadius,
                      ),
                    ),
                  ),
                ),
                child: action,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppSurfaceBackdrop extends StatelessWidget {
  final Widget child;

  const AppSurfaceBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? AppAdaptivePalette.darkBackground
            : AppAdaptivePalette.background,
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
                            AppAdaptivePalette.telegramBlue.withValues(
                              alpha: 0.12,
                            ),
                            Colors.transparent,
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.68),
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
