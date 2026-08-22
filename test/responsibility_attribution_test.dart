import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Contract for visible authorship in tasks and timesheets.
void main() {
  test('task list loads responsibility in parallel', () {
    final source = File('lib/data/task_repository.dart').readAsStringSync();
    expect(source, contains('get_task_responsibility_fast'));
    expect(source, contains('Future.wait<dynamic>'));
    expect(source, contains('creator: creator'));
    expect(source, contains('lastEditor: lastEditor'));
  });

  test('responsibility UI shows initials and reveals short name', () {
    final source = File(
      'lib/widgets/responsibility_actor_line.dart',
    ).readAsStringSync();
    expect(source, contains(".take(2)"));
    expect(source, contains('part.characters.first.toUpperCase()'));
    expect(source, contains('_InitialsAvatar'));
    expect(source, contains('TooltipTriggerMode.tap'));
    expect(source, contains("return '\${parts[1]} \${parts[0]}'"));
    expect(source, contains('preferBelow: false'));
    expect(source, isNot(contains('ProfileAvatarService')));
    expect(source, isNot(contains('Image.network')));
    expect(source, isNot(contains("text: actor.fullName")));
  });

  test('task responsibility is visible in mobile and both desktop tables', () {
    final mobile = File('lib/widgets/task_tile.dart').readAsStringSync();
    final desktop = File(
      'lib/screens/desktop_tasks_screen.dart',
    ).readAsStringSync();
    final foremanDesktop = File(
      'lib/features/foreman/presentation/foreman_task_table.dart',
    ).readAsStringSync();

    expect(mobile, contains('ResponsibilityActorLine'));
    expect(desktop, contains('_TaskResponsibilityMeta'));
    expect(desktop, contains('ResponsibilityActorLine'));
    expect(foremanDesktop, contains('_TaskWorkWithResponsibility'));
    expect(foremanDesktop, contains('ResponsibilityActorLine'));
    expect(mobile, contains("label: 'Создал и изменил'"));
    expect(desktop, contains("label: 'Создал и изменил'"));
  });

  test('desktop task table fills wide screens and keeps small-screen scroll', () {
    final desktop = File(
      'lib/screens/desktop_tasks_screen.dart',
    ).readAsStringSync();
    expect(desktop, contains('LayoutBuilder'));
    expect(desktop, contains('constraints.maxWidth < 1320'));
    expect(desktop, contains('width: tableWidth'));
    expect(desktop, contains('BoxConstraints(minHeight: 82)'));
  });

  test('timesheet exposes latest editor on mobile and desktop', () {
    final mobile = File(
      'lib/screens/timesheet/timesheet_sections.dart',
    ).readAsStringSync();
    final desktop = File(
      'lib/screens/desktop_timesheet_screen.dart',
    ).readAsStringSync();
    expect(mobile, contains("label: 'Последнее изменение'"));
    expect(desktop, contains("label: 'Изменил'"));
    expect(mobile, contains('ResponsibilityActorLine'));
    expect(desktop, contains('ResponsibilityActorLine'));
  });

  test(
    'responsibility RPCs are authenticated-only and reuse visibility RPCs',
    () {
      final sql = File(
        'supabase/migrations/20260822094500_task_timesheet_responsibility.sql',
      ).readAsStringSync();
      expect(sql, contains('get_task_responsibility_fast'));
      expect(sql, contains('get_attendance_responsibility_fast'));
      expect(sql, contains('from public.get_task_rows_fast'));
      expect(sql, contains('from public.get_attendance_rows_fast'));
      expect(sql, contains('grant execute'));
      expect(sql, contains('to authenticated'));
      expect(sql, isNot(contains('profile avatars select company peers')));
    },
  );
}
