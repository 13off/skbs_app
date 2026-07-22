import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Контракт фиксирует именно дефекты, найденные на мобильных скриншотах.
  test('dark mobile screens use the adaptive palette', () {
    for (final path in <String>[
      'lib/screens/home_screen.dart',
      'lib/screens/employees_screen.dart',
      'lib/screens/mobile_tasks_screen.dart',
      'lib/features/role_preview/role_preview_screen.dart',
      'lib/screens/timesheet/timesheet_sections.dart',
      'lib/screens/timesheet/timesheet_view.dart',
      'lib/features/milestones/presentation/milestone_home_overlay.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('AppAdaptivePalette'),
        reason: '$path must use the active light/dark palette.',
      );
    }
  });

  test('reported bright mobile surfaces are removed from dark mode', () {
    final employees = File(
      'lib/screens/employees/employees_sections.dart',
    ).readAsStringSync();
    expect(employees, isNot(contains('Colors.white.withValues(alpha: 0.88)')));

    final timesheet = File(
      'lib/screens/timesheet/timesheet_view.dart',
    ).readAsStringSync();
    expect(timesheet, isNot(contains('Colors.white.withValues(alpha: 0.82)')));

    final tasks = File(
      'lib/screens/mobile_tasks_screen.dart',
    ).readAsStringSync();
    expect(tasks, isNot(contains('const Color _tasksText')));
  });
}
