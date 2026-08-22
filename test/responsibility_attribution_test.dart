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

  test('responsibility UI shows initials without full name or profile photo', () {
    final source = File(
      'lib/widgets/responsibility_actor_line.dart',
    ).readAsStringSync();
    expect(source, contains(".take(2)"));
    expect(source, contains('part.characters.first.toUpperCase()'));
    expect(source, contains('_InitialsAvatar'));
    expect(source, isNot(contains('ProfileAvatarService')));
    expect(source, isNot(contains('Image.network')));
    expect(source, isNot(contains("text: actor.fullName")));
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
