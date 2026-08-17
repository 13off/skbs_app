import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persistent workspaces share one glass visual contract', () {
    final shell = File(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('_workDepth = 1.28'));
    expect(shell, contains('_workCardRadius = 22'));
    expect(shell, contains('compactPageLayout: true'));
    expect(shell, contains('hidePageSubtitles: true'));
    expect(shell, contains('LiquidGlassStyleScope'));
  });

  test('role router keeps the same visual contract around every platform', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(main, contains('_workDepth = 1.28'));
    expect(main, contains('_workCardRadius = 22'));
    expect(main, contains('workVisualScope'));
    expect(main, contains('CompanyChatShell'));
    expect(main, contains('LiquidGlassStyleScope'));
  });

  test('all primary role platforms remain routed through shared shells', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    for (final platform in <String>[
      'EmployeePlatformWithPassport',
      'DeveloperMainScreen',
      'LegalMainScreen',
      'AccountingMainScreen',
      'RecruitmentMainScreen',
      'ProcurementMainScreen',
      'ManagerMainScreen',
      'ForemanMainScreen',
      'premium.MainScreen',
    ]) {
      expect(main, contains(platform));
    }
  });

  test('lawyer no longer owns a separate visual override', () {
    final legal = File(
      'lib/features/legal/presentation/legal_main_screen.dart',
    ).readAsStringSync();

    expect(legal, contains('PersistentTabShell'));
    expect(legal, isNot(contains('legalRoot')));
    expect(legal, isNot(contains('depth: 1.28')));
    expect(legal, isNot(contains('cardRadius: 22')));
  });
}
