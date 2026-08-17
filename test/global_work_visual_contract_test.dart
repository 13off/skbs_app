import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persistent workspaces own the single glass visual contract', () {
    final shell = File(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('workDepth = 1.28'));
    expect(shell, contains('workCardRadius = 22'));
    expect(shell, contains('depth: PersistentTabShell.workDepth'));
    expect(shell, contains('cardRadius: PersistentTabShell.workCardRadius'));
    expect(shell, contains('compactPageLayout: true'));
    expect(shell, contains('hidePageSubtitles: true'));
    expect(shell, contains('LiquidGlassStyleScope'));
  });

  test('role router reuses shell visual tokens around every platform', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(main, contains('PersistentTabShell.workDepth'));
    expect(main, contains('PersistentTabShell.workCardRadius'));
    expect(main, contains('workVisualScope'));
    expect(main, contains('CompanyChatShell'));
    expect(main, contains('LiquidGlassStyleScope'));
    expect(main, isNot(contains('_workDepth = 1.28')));
    expect(main, isNot(contains('_workCardRadius = 22')));
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
