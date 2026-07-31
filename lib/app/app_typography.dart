import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Единая типографика AppСтрой.
///
/// Inter сохраняет заданные размеры, веса и интервалы текущей темы, но меняет
/// семейство шрифта сразу для светлого и тёмного интерфейса.
abstract final class AppTypography {
  static ThemeData apply(ThemeData theme) {
    return theme.copyWith(
      textTheme: GoogleFonts.interTextTheme(theme.textTheme),
      primaryTextTheme: GoogleFonts.interTextTheme(theme.primaryTextTheme),
    );
  }
}
