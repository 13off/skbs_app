import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('desktop pages use the available width with one shared margin', () {
    final tokens = source('lib/app/app_ui_tokens.dart');
    final page = source('lib/widgets/app_page.dart');
    final navigation = source(
      'lib/widgets/professional_bottom_navigation.dart',
    );

    expect(tokens, contains('pageDesktopHorizontalPadding = 48'));
    expect(tokens, contains('desktopNavigationMaxWidth = 945'));
    expect(page, contains('final effectiveMaxContentWidth = isDesktop'));
    expect(page, contains('? double.infinity'));
    expect(navigation, contains('AppUi.desktopNavigationMaxWidth'));
    expect(navigation, isNot(contains('maxWidth: isDesktop ? 900')));
  });

  test('custom desktop workspaces no longer use narrow page caps', () {
    final files = <String, String>{
      'lib/screens/adaptive_home_base_screen.dart': '1240',
      'lib/screens/desktop_employees_view.dart': '1400',
      'lib/screens/desktop_tasks_screen.dart': '1400',
      'lib/screens/desktop_timesheet_screen.dart': '1320',
      'lib/features/payments/presentation/screens/payments_screen.dart': '1360',
      'lib/features/milestones/presentation/milestones_screen.dart': '1060',
      'lib/features/milestones/presentation/milestone_detail_screen.dart':
          '980',
    };

    for (final entry in files.entries) {
      final file = source(entry.key);
      expect(
        file,
        matches(
          RegExp(
            r'constraints:\s*const\s+BoxConstraints\(\s*maxWidth:\s*double\.infinity\s*,?\s*\)',
          ),
        ),
        reason: entry.key,
      );
      expect(
        file,
        isNot(contains('BoxConstraints(maxWidth: ${entry.value})')),
        reason: entry.key,
      );
    }
  });

  test('mobile page limits remain intact', () {
    expect(
      source('lib/screens/home/home_sections.dart'),
      contains('BoxConstraints(maxWidth: 620)'),
    );
    expect(
      source('lib/screens/employees/employees_view.dart'),
      contains('BoxConstraints(maxWidth: 760)'),
    );
    expect(
      source('lib/screens/timesheet/timesheet_view.dart'),
      contains('BoxConstraints(maxWidth: 860)'),
    );
  });
}
