import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Единая типографика AppСтрой.
///
/// Inter сохраняет заданные размеры, веса и интервалы текущей темы, но меняет
/// семейство шрифта сразу для светлого и тёмного интерфейса, включая системные
/// кнопки, диалоги, меню и шапки.
abstract final class AppTypography {
  static TextStyle? _inter(TextStyle? style) {
    if (style == null) return null;
    return GoogleFonts.inter(textStyle: style);
  }

  static ButtonStyle? _buttonStyle(ButtonStyle? style) {
    if (style == null) return null;
    final source = style.textStyle;
    if (source == null) return style;

    return style.copyWith(
      textStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        return _inter(source.resolve(states));
      }),
    );
  }

  static ThemeData apply(ThemeData theme) {
    final textTheme = GoogleFonts.interTextTheme(theme.textTheme);
    final primaryTextTheme = GoogleFonts.interTextTheme(theme.primaryTextTheme);

    return theme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: _inter(theme.appBarTheme.titleTextStyle),
        toolbarTextStyle: _inter(theme.appBarTheme.toolbarTextStyle),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        titleTextStyle: _inter(theme.dialogTheme.titleTextStyle),
        contentTextStyle: _inter(theme.dialogTheme.contentTextStyle),
      ),
      popupMenuTheme: theme.popupMenuTheme.copyWith(
        textStyle: _inter(theme.popupMenuTheme.textStyle),
      ),
      snackBarTheme: theme.snackBarTheme.copyWith(
        contentTextStyle: _inter(theme.snackBarTheme.contentTextStyle),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(theme.filledButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(theme.elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonStyle(theme.textButtonTheme.style),
      ),
    );
  }
}
