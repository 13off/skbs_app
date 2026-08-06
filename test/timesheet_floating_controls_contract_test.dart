import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop download action stays inside the timesheet toolbar', () {
    final adaptive = File(
      'lib/screens/adaptive_timesheet_screen.dart',
    ).readAsStringSync();
    final desktop = File(
      'lib/screens/desktop_timesheet_screen.dart',
    ).readAsStringSync();

    expect(adaptive, contains('onDownload: downloadAction'));
    expect(desktop, contains('final VoidCallback? onDownload'));
    expect(desktop, contains("label: const Text('Скачать табель')"));
  });

  test('save action is a compact floating card directly above navigation', () {
    final desktop = File(
      'lib/screens/desktop_timesheet_screen.dart',
    ).readAsStringSync();

    expect(
      desktop,
      contains('constraints: const BoxConstraints(maxWidth: 620)'),
    );
    expect(desktop, contains('bottom: AppUi.navigationTotalHeight(context)'));
    expect(desktop, isNot(contains('bottom: 112')));
    expect(
      desktop,
      isNot(contains('border: Border(top: BorderSide(color: _line))')),
    );
  });

  test('main shell reserves a real layout area for bottom navigation', () {
    final shell = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();

    expect(shell, contains('bottomNavigationBar: _PremiumBottomBar('));
    expect(shell, isNot(contains('extendBody: true')));
    expect(shell, isNot(contains('legacy-tab-content-clearance')));
    expect(
      shell,
      contains('backgroundColor: Theme.of(context).scaffoldBackgroundColor'),
    );
  });
}
