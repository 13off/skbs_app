import 'package:flutter/material.dart';

/// Единые размеры интерфейса AppСтрой.
///
/// Страницы и рабочие модули не должны задавать собственную геометрию для
/// одинаковых элементов. Новые экраны используют эти значения напрямую, а
/// базовые ThemeData/AppPage/PremiumWorkCard распространяют их на старые.
abstract final class AppUi {
  static const double desktopBreakpoint = 1050;
  static const double specialistDesktopBreakpoint = 820;

  static const double pageMobileHorizontalPadding = 16;
  static const double pageDesktopHorizontalPadding = 36;
  static const double pageMobileTopPadding = 14;
  static const double pageDesktopTopPadding = 24;
  static const double pageBottomPadding = 132;
  static const double pageContentWidth = 1220;
  static const double specialistContentWidth = 1460;

  static const double pageHeaderMinHeight = 68;
  static const double pageHeaderActionSize = 54;
  static const double pageHeaderGap = 22;

  static const double controlHeight = 56;
  static const double compactControlHeight = 48;
  static const double controlRadius = 19;
  static const double cardRadius = 28;
  static const double modalRadius = 32;
  static const double cardPadding = 22;
  static const double desktopActionMaxWidth = 420;

  static const double mobileNavigationPanelHeight = 76;
  static const double desktopNavigationPanelHeight = 78;
  static const double mobileNavigationTopSpacing = 7;
  static const double desktopNavigationTopSpacing = 10;
  static const double mobileNavigationBottomSpacing = 11;
  static const double desktopNavigationBottomSpacing = 16;
  static const double floatingActionGap = 10;

  static const double gap4 = 4;
  static const double gap8 = 8;
  static const double gap12 = 12;
  static const double gap16 = 16;
  static const double gap20 = 20;
  static const double gap24 = 24;
  static const double gap32 = 32;

  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);
  static const EdgeInsets controlInsets = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 15,
  );

  static bool usesDesktopNavigation(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= specialistDesktopBreakpoint;
  }

  static double navigationPanelHeight(BuildContext context) {
    return usesDesktopNavigation(context)
        ? desktopNavigationPanelHeight
        : mobileNavigationPanelHeight;
  }

  static double navigationTopSpacing(BuildContext context) {
    return usesDesktopNavigation(context)
        ? desktopNavigationTopSpacing
        : mobileNavigationTopSpacing;
  }

  static double navigationBottomSpacing(BuildContext context) {
    return usesDesktopNavigation(context)
        ? desktopNavigationBottomSpacing
        : mobileNavigationBottomSpacing;
  }

  static double navigationTotalHeight(BuildContext context) {
    return navigationPanelHeight(context) +
        navigationTopSpacing(context) +
        navigationBottomSpacing(context) +
        MediaQuery.viewPaddingOf(context).bottom;
  }

  static double floatingActionBottom(
    BuildContext context, {
    double gap = floatingActionGap,
  }) {
    return navigationTotalHeight(context) + gap;
  }

  static double floatingActionListBottomPadding(
    BuildContext context, {
    double actionHeight = 64,
    double gap = 22,
  }) {
    return navigationTotalHeight(context) + actionHeight + gap;
  }
}
