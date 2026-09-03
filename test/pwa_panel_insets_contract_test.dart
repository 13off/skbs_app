import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('wide PWA keeps the page background full width and insets panels', () {
    final main = source('lib/main.dart');
    final page = source('lib/widgets/app_page.dart');
    final tokens = source('lib/app/app_ui_tokens.dart');

    expect(main, contains('builder: (context, child) => AppScaleViewport('));
    expect(main, isNot(contains('PwaDesktopPageFrame(')));
    expect(page, isNot(contains('PwaDesktopPageFrame.isApplied')));
    expect(page, contains('? AppUi.pageDesktopHorizontalPadding'));
    expect(tokens, contains('pageDesktopHorizontalPadding = 48'));
    expect(tokens, contains('desktopNavigationMaxWidth = 945'));
  });

  test('custom desktop workspaces use the same panel inset', () {
    for (final path in <String>[
      'lib/screens/adaptive_home_base_screen.dart',
      'lib/screens/desktop_employees_view.dart',
      'lib/screens/desktop_tasks_screen.dart',
      'lib/screens/desktop_timesheet_screen.dart',
      'lib/features/payments/presentation/screens/payments_screen.dart',
      'lib/features/milestones/presentation/milestones_screen.dart',
      'lib/features/milestones/presentation/milestone_detail_screen.dart',
    ]) {
      expect(
        source(path),
        contains('AppUi.pageDesktopHorizontalPadding'),
        reason: path,
      );
    }
  });
}
