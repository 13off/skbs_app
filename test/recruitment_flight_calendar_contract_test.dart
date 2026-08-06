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

  test('calendar exposes month view, ticket editor and employee reminder', () {
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
    expect(screen, contains('Напомнить сотруднику'));
    expect(screen, contains('RecruitmentMobilizationScreen'));
    expect(main, contains('RecruitmentFlightCalendarScreen'));
    expect(main, contains("label: 'Вылеты'"));
  });

  test('manual and due reminders target app and bot channels once', () {
    final migration = source(
      'supabase/migrations/20260806123000_recruitment_flight_calendar.sql',
    );
    final repository = source(
      'lib/features/recruitment/data/recruitment_flight_repository.dart',
    );

    expect(migration, contains('send_recruitment_flight_reminder'));
    expect(migration, contains('dispatch_due_recruitment_flight_reminders'));
    expect(migration, contains('day_before_sent_at is null'));
    expect(migration, contains('three_hours_sent_at is null'));
    expect(migration, contains("'recruitment_flight'"));
    expect(repository, contains('PushNotificationService.dispatchNotification'));
    expect(repository, contains('RecruitmentRepository.sendCandidateMessage'));
  });
}
