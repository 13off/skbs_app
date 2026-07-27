import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Контракт одновременно защищает live-переключение и сохранение текущего state.
  test('working platform rebuilds when inherited theme changes', () {
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final adaptivePalette = File(
      'lib/app/app_adaptive_palette.dart',
    ).readAsStringSync();

    final themeDependency = mainScreen.indexOf('Theme.of(context);');
    final platformBuild = mainScreen.indexOf('return FutureBuilder<void>(');

    expect(themeDependency, greaterThanOrEqualTo(0));
    expect(platformBuild, greaterThan(themeDependency));
    expect(
      mainScreen,
      isNot(contains("ValueKey<String>('theme:")),
      reason: 'Смена темы не должна сбрасывать состояние текущей страницы.',
    );
    expect(
      adaptivePalette,
      contains('AppThemeController.instance.isDark'),
      reason: 'Корневой rebuild нужен для глобальной адаптивной палитры.',
    );
  });
}
