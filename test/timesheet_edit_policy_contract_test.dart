import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/developer/models/task_policy.dart';

void main() {
  group('TaskPolicy timesheet window', () {
    final today = DateTime(2026, 9, 6);

    test('null keeps historical editing unlimited', () {
      const policy = TaskPolicy(foremanTimesheetEditWindowDays: null);
      expect(
        policy.canForemanEditTimesheetDate(DateTime(2020, 1, 1), today: today),
        isTrue,
      );
      expect(
        policy.toJson()['foreman_timesheet_edit_window_days'],
        isNull,
      );
    });

    test('zero means today only while future dates stay unchanged', () {
      const policy = TaskPolicy(foremanTimesheetEditWindowDays: 0);
      expect(
        policy.canForemanEditTimesheetDate(DateTime(2026, 9, 5), today: today),
        isFalse,
      );
      expect(policy.canForemanEditTimesheetDate(today, today: today), isTrue);
      expect(
        policy.canForemanEditTimesheetDate(DateTime(2026, 9, 7), today: today),
        isTrue,
      );
    });

    test('configured number includes exactly that many previous days', () {
      const policy = TaskPolicy(foremanTimesheetEditWindowDays: 2);
      expect(
        policy.canForemanEditTimesheetDate(DateTime(2026, 9, 4), today: today),
        isTrue,
      );
      expect(
        policy.canForemanEditTimesheetDate(DateTime(2026, 9, 3), today: today),
        isFalse,
      );
    });

    test('round-trips the database field', () {
      final policy = TaskPolicy.fromJson(
        const <String, dynamic>{'foreman_timesheet_edit_window_days': 5},
      );
      expect(policy.foremanTimesheetEditWindowDays, 5);
      expect(policy.toJson()['foreman_timesheet_edit_window_days'], 5);
    });
  });

  test('developer panel exposes dedicated timesheet setting', () {
    final source = File(
      'lib/features/developer/presentation/timesheet_edit_policy_screen.dart',
    ).readAsStringSync();
    final system = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Редактирование предыдущих дней'));
    expect(source, contains('Только текущий день'));
    expect(source, contains('Без ограничения'));
    expect(source, contains('foremanTimesheetEditWindowDays'));
    expect(system, contains("title: 'Редактирование табеля'"));
  });

  test('mobile timesheet blocks editing and saving for locked dates', () {
    final screen = File('lib/screens/timesheet_screen.dart').readAsStringSync();
    final actions = File(
      'lib/screens/timesheet/timesheet_actions.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/timesheet/timesheet_sections.dart',
    ).readAsStringSync();
    final view = File('lib/screens/timesheet/timesheet_view.dart').readAsStringSync();

    expect(screen, contains("widget.profile.actualRole == 'foreman'"));
    expect(screen, contains('canEditSelectedTimesheetDate'));
    expect(actions, contains('if (!canEditSelectedTimesheetDate) return;'));
    expect(sections, contains('Эта дата уже закрыта для редактирования прорабом'));
    expect(view, contains('!canEditSelectedTimesheetDate'));
  });

  test('migration stores policy and enforces it in attendance RLS', () {
    final migration = File(
      'supabase/migrations/20260906165000_add_timesheet_edit_window_policy.sql',
    ).readAsStringSync();

    expect(migration, contains('foreman_timesheet_edit_window_days'));
    expect(migration, contains('current_user_can_edit_attendance_date'));
    expect(migration, contains('attendance_insert_company_object'));
    expect(migration, contains('attendance_update_company_object'));
    expect(migration, contains("v_role is distinct from 'foreman'"));
  });
}
