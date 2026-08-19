import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/recruitment/models/recruitment_flight_models.dart';

void main() {
  test('flight reminder labels describe event and offset', () {
    const departure = RecruitmentFlightReminder(
      eventKind: 'departure',
      offsetMinutes: 180,
    );
    const arrival = RecruitmentFlightReminder(
      eventKind: 'arrival',
      offsetMinutes: 0,
    );

    expect(departure.label, 'За 3 ч до отправления');
    expect(arrival.label, 'В момент прибытия');
    expect(departure.toPayload(), <String, dynamic>{
      'event_kind': 'departure',
      'offset_minutes': 180,
    });
  });

  test('flight editor uses configurable reminders instead of fixed switches', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("'Напомнить за сутки'")));
    expect(source, isNot(contains("'Напомнить за 3 часа'")));
    expect(source, contains("'Добавить уведомление'"));
    expect(source, contains('RecruitmentFlightReminder'));
    expect(source, contains('Такое уведомление уже добавлено'));
    expect(source, contains('Время прибытия'));
  });

  test('flight reminder persistence has cascade and exact duplicate guard', () {
    final repository = File(
      'lib/features/recruitment/data/recruitment_flight_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260819150000_recruitment_flight_custom_reminders.sql',
    ).readAsStringSync();

    expect(repository, contains("from('recruitment_flight_reminders')"));
    expect(repository, contains("'replace_recruitment_flight_reminders'"));
    expect(migration, contains('create table if not exists public.recruitment_flight_reminders'));
    expect(migration, contains('on delete cascade'));
    expect(migration, contains('unique (flight_id, event_kind, offset_minutes)'));
    expect(migration, contains('offset_minutes between 0 and 43200'));
    expect(migration, contains('dispatch_due_recruitment_flight_reminders'));
    expect(migration, contains("'departure',\n  1440"));
    expect(migration, contains("'departure',\n  180"));
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
