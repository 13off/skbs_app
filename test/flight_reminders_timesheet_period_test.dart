import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/recruitment/models/recruitment_flight_models.dart';

void main() {
  test('flight reminder stores exact chosen date and time', () {
    final reminder = RecruitmentFlightReminder(
      remindAt: DateTime(2026, 8, 25, 18, 30),
    );

    expect(reminder.label, '25.08.2026 · 18:30');
    expect(
      reminder.toPayload()['remind_at'],
      reminder.remindAt.toUtc().toIso8601String(),
    );
  });

  test('flight editor asks only for reminder date and time', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart',
    ).readAsStringSync();

    expect(source, contains("'Добавить уведомление'"));
    expect(source, contains('final value = await chooseDateTime(initial);'));
    expect(source, contains('RecruitmentFlightReminder(remindAt: normalized)'));
    expect(source, isNot(contains("labelText: 'Событие'")));
    expect(source, isNot(contains("labelText: 'Когда напомнить'")));
    expect(source, isNot(contains("'За 15 минут'")));
    expect(source, isNot(contains("'За 3 часа'")));
    expect(source, isNot(contains("'За 24 часа'")));
    expect(source, isNot(contains("'Свой вариант'")));
    expect(source, isNot(contains("'Напомнить сотруднику'")));
    expect(source, contains('Future<void> chooseArrival() async'));
    expect(source, contains("'Убрать время прибытия'"));
  });

  test('personal flight reminder is owner scoped and cron scheduled', () {
    final repository = File(
      'lib/features/recruitment/data/recruitment_flight_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260819170000_personal_flight_reminder_datetime.sql',
    ).readAsStringSync();

    expect(repository, contains("from('recruitment_flight_reminders')"));
    expect(repository, contains("'replace_recruitment_flight_reminders'"));
    expect(repository, contains('reminder.remindAt'));
    expect(migration, contains('remind_at timestamptz'));
    expect(migration, contains('target_user_id uuid references auth.users(id)'));
    expect(migration, contains('target_user_id = (select auth.uid())'));
    expect(migration, contains('process_due_recruitment_flight_personal_reminders'));
    expect(migration, contains("'appstroy-flight-personal-reminders'"));
    expect(migration, contains("'* * * * *'"));
    expect(migration, contains("'Напоминание о вылете'"));
    expect(migration, contains("'recruitment_flight_reminder'"));
    expect(migration, contains('v_due.target_user_id'));
  });

  test('individual timesheet supports multiple months, exact range and balance', () {
    final screen = File('lib/screens/employee_timesheet_screen.dart')
        .readAsStringSync();
    final repository = File('lib/data/attendance_repository.dart')
        .readAsStringSync();

    expect(screen, contains('_EmployeeTimesheetPeriodMode.months'));
    expect(screen, contains('_EmployeeTimesheetPeriodMode.dates'));
    expect(screen, contains('Set<DateTime> selectedMonths'));
    expect(screen, contains('showDateRangePicker'));
    expect(screen, contains("label: 'Остаток за выбранное'"));
    expect(screen, contains("return '\$text рублей';"));
    expect(repository, contains('fetchTimesheetForEmployeePeriod'));
    expect(repository, contains(".gte('payment_date', dateKey(cleanStart))"));
    expect(repository, contains(".lte('payment_date', dateKey(cleanEnd))"));
  });
}
