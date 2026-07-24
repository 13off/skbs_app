import 'package:flutter/material.dart';

/// Единые размеры интерфейса AppСтрой.
///
/// Страницы и рабочие модули не должны задавать собственную геометрию для
/// одинаковых элементов. Новые экраны используют эти значения напрямую, а
/// базовые ThemeData/AppPage/PremiumWorkCard распространяют их на старые.
abstract final class AppUi {
  static const double desktopBreakpoint = 1050;
  static const double specialistDesktopBreakpoint = 820;

  static const double pageMobileHorizontalPadding = 14;
  static const double pageDesktopHorizontalPadding = 24;
  static const double pageMobileTopPadding = 12;
  static const double pageDesktopTopPadding = 20;
  static const double pageBottomPadding = 120;
  static const double pageContentWidth = 1180;
  static const double specialistContentWidth = 1460;

  static const double pageHeaderMinHeight = 54;
  static const double pageHeaderActionSize = 44;
  static const double pageHeaderGap = 16;

  static const double controlHeight = 48;
  static const double compactControlHeight = 42;
  static const double controlRadius = 16;
  static const double cardRadius = 22;
  static const double modalRadius = 26;
  static const double cardPadding = 18;

  static const double gap4 = 4;
  static const double gap8 = 8;
  static const double gap12 = 12;
  static const double gap16 = 16;
  static const double gap20 = 20;
  static const double gap24 = 24;
  static const double gap32 = 32;

  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);
  static const EdgeInsets controlInsets = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );
}
