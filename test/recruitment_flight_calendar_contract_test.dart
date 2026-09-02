import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('HR flight calendar stores tickets and exact departure data', () {
    final migration = source(
      'supabase/migrations/20260806123000_recruitment_flight_calendar.sql',
    );
    final repository = source(
      'lib/features/recruitment/data/recruitment_flight_repository.dart',
    );
    final models = source(
      'lib/features/recruitment/models/recruitment_flight_models.dart',
    );

    expect(migration, contains('public.recruitment_flights'));
    expect(migration, contains('departure_at timestamptz not null'));
    expect(migration, contains('ticket_path text not null'));
    expect(migration, contains('remind_day_before'));
    expect(migration, contains('remind_three_hours'));
    expect(migration, contains('enable row level security'));
    expect(repository, contains("ticketBucket = 'recruitment-documents'"));
    expect(repository, contains('uploadBinary('));
    expect(repository, contains(".from('recruitment_flights')"));
    expect(repository, contains(".from('employee_mobilizations').upsert("));
    expect(models, contains('class RecruitmentFlight'));
    expect(models, contains('class RecruitmentFlightCalendarData'));
  });

  test('calendar exposes month view, multi-leg ticket editor and personal reminder', () {
    final screen = source(
      'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart',
    );
    final main = source(
      'lib/features/recruitment/presentation/recruitment_main_screen.dart',
    );

    expect(screen, contains("title: 'Календарь вылетов'"));
    expect(screen, contains('GridView.builder('));
    expect(screen, contains('Добавить вылет и билет'));
    expect(screen, contains('Прикрепить билет'));
    expect(screen, contains('Добавить уведомление'));
    expect(screen, isNot(contains('Напомнить сотруднику')));
    expect(screen, contains('Future<void> chooseDeparture(int index) async'));
    expect(screen, contains('Future<void> chooseArrival(int index) async'));
    expect(screen, contains("label: const Text('Добавить рейс')"));
    expect(screen, contains('segments: segmentValues'));
    expect(screen, contains('RecruitmentMobilizationScreen'));
    expect(main, contains('RecruitmentFlightCalendarScreen'));
    expect(main, contains("label: 'Вылеты'"));
  });

  test('scheduled flight reminder is personal and exact-time based', () {
    final migration = source(
      'supabase/migrations/20260819170000_personal_flight_reminder_datetime.sql',
    );
    final repository = source(
      'lib/features/recruitment/data/recruitment_flight_repository.dart',
    );
    final models = source(
      'lib/features/recruitment/models/recruitment_flight_models.dart',
    );

    expect(migration, contains('remind_at timestamptz'));
    expect(migration, contains('target_user_id uuid references auth.users(id)'));
    expect(migration, contains('target_user_id = (select auth.uid())'));
    expect(migration, contains("'* * * * *'"));
    expect(migration, contains("'Напоминание о вылете'"));
    expect(repository, contains("'replace_recruitment_flight_reminders'"));
    expect(models, contains("'remind_at': remindAt.toUtc().toIso8601String()"));
  });

  // Arrival/departure remain flight data; reminders are private notifications for the creator.
}
