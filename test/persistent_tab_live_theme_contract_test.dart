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
    expect(shell, contains('widget.tabBuilder(context, index)'));
    expect(shell, contains('final rootPage = overrideBuilder != null'));
    expect(shell, contains('child: rootPage'));

    expect(
      shell,
      isNot(contains("ValueKey<String>('theme:")),
      reason: 'Theme changes must not recreate nested Navigator state.',
    );
    expect(
      shell,
      contains('final Map<int, Widget> _tabNavigators'),
      reason: 'Nested tab cache and navigation history must stay alive.',
    );
  });
}
