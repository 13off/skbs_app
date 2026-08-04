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
  static const double pageDesktopHorizontalPadding = 30;
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

  // The main shell paints its body behind this navigation. Any fixed action
  // inside a tab must use these same metrics instead of a hard-coded bottom.
  static const double mobileBottomNavigationPanelHeight = 76;
  static const double desktopBottomNavigationPanelHeight = 78;
  static const double mobileBottomNavigationTopSpacing = 7;
  static const double desktopBottomNavigationTopSpacing = 10;
  static const double mobileBottomNavigationBottomSpacing = 11;
  static const double desktopBottomNavigationBottomSpacing = 16;
  static const double bottomActionNavigationGap = 8;
  static const double bottomActionContentGap = 18;

  static bool usesDesktopBottomNavigation(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= specialistDesktopBreakpoint;
  }

  static double bottomNavigationPanelHeight(BuildContext context) {
    return usesDesktopBottomNavigation(context)
        ? desktopBottomNavigationPanelHeight
        : mobileBottomNavigationPanelHeight;
  }

  static double bottomNavigationTopSpacing(BuildContext context) {
    return usesDesktopBottomNavigation(context)
        ? desktopBottomNavigationTopSpacing
        : mobileBottomNavigationTopSpacing;
  }

  static double bottomNavigationBottomSpacing(BuildContext context) {
    return usesDesktopBottomNavigation(context)
        ? desktopBottomNavigationBottomSpacing
        : mobileBottomNavigationBottomSpacing;
  }

  static double bottomNavigationHeight(BuildContext context) {
    return bottomNavigationPanelHeight(context) +
        bottomNavigationTopSpacing(context) +
        bottomNavigationBottomSpacing(context) +
        MediaQuery.viewPaddingOf(context).bottom;
  }

  static double bottomActionOffset(BuildContext context) {
    return bottomNavigationHeight(context) + bottomActionNavigationGap;
  }

  static double bottomActionContentPadding(BuildContext context) {
    return bottomActionOffset(context) + controlHeight + bottomActionContentGap;
  }

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
}
