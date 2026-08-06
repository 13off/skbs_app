import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all tab shells reserve the floating navigation area', () {
    final persistent = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );
    final legacy = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );
    final tokens = source('lib/app/app_ui_tokens.dart');

    for (final shell in <String>[persistent, legacy]) {
      expect(shell, contains('AppUi.navigationTotalHeight(context)'));
      expect(
        shell,
        contains('padding: EdgeInsets.only(bottom: navigationClearance)'),
      );
      expect(
        shell,
        contains('padding: mediaQuery.padding.copyWith(bottom: 0)'),
      );
      expect(
        shell,
        contains('viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0)'),
      );
    }

    expect(
      persistent,
      contains("ValueKey('persistent-tab-content-clearance')"),
    );
    expect(legacy, contains("ValueKey('legacy-tab-content-clearance')"));
    expect(tokens, contains('static const double pageBottomPadding = 32;'));
  });
}
