import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

// This contract also triggers publication of the verified non-overlay shell.
void main() {
  test('all tab shells keep navigation outside the screen body', () {
    final persistent = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );
    final legacy = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expect(
      persistent,
      contains('bottomNavigationBar: ProfessionalBottomNavigation('),
    );
    expect(persistent, isNot(contains('_DesktopTabRail(')));
    expect(legacy, contains('bottomNavigationBar: _PremiumBottomBar('));

    for (final shell in <String>[persistent, legacy]) {
      expect(shell, isNot(contains('extendBody: true')));
      expect(shell, isNot(contains('navigationClearance')));
      expect(shell, isNot(contains('content-clearance')));
      expect(shell, contains('backgroundColor: Colors.transparent'));
    }
  });
}
