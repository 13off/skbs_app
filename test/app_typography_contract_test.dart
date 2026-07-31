import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark app themes are wrapped by one Inter typography layer', () {
    final main = File('lib/main.dart').readAsStringSync();
    final typography = File('lib/app/app_typography.dart').readAsStringSync();

    expect(main, contains("import 'app/app_typography.dart';"));
    expect(main, contains('theme: AppTypography.apply('));
    expect(main, contains('darkTheme: AppTypography.apply(AppDarkTheme.theme)'));
    expect(typography, contains('GoogleFonts.interTextTheme'));
    expect(typography, contains('GoogleFonts.inter(textStyle: style)'));
    expect(typography, contains('filledButtonTheme: FilledButtonThemeData('));
    expect(typography, contains('appBarTheme: theme.appBarTheme.copyWith('));
  });
}
