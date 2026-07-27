import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached persistent tabs rebuild on live theme changes', () {
    final shell = File(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    ).readAsStringSync();

    expect(shell, contains("import '../../../app/theme_controller.dart';"));
    expect(shell, contains('animation: AppThemeController.instance'));
    expect(shell, contains('Theme.of(context);'));
    expect(shell, contains('return widget.tabBuilder(context, index);'));

    expect(
      shell,
      isNot(contains("ValueKey<String>('theme:")),
      reason: 'Смена темы не должна пересоздавать Navigator и терять вкладку.',
    );
    expect(
      shell,
      contains('final Map<int, Widget> _tabNavigators'),
      reason: 'Кэш и история вложенных вкладок должны сохраняться.',
    );
  });
}
