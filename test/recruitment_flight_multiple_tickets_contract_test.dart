import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('flight attachments are normalized and old tickets are backfilled', () {
    final migration = source(
      'supabase/migrations/20260811061224_recruitment_flight_multiple_tickets.sql',
    );

    expect(migration, contains('public.recruitment_flight_tickets'));
    expect(migration, contains('flight_id uuid not null'));
    expect(migration, contains('references public.recruitment_flights(id)'));
    expect(migration, contains('Backfill every old single-ticket flight'));
    expect(migration, contains('from public.recruitment_flights flight'));
    expect(migration, contains('on conflict (company_id, path) do nothing'));
    expect(migration, contains('enable row level security'));
    expect(
      migration,
      contains(
        'grant select, insert, delete on table public.recruitment_flight_tickets to authenticated',
      ),
    );
    expect(
      migration,
      contains("current_user_has_permission('recruitment.applications.edit')"),
    );
  });

  test('repository loads and appends several ticket files', () {
    final repository = source(
      'lib/features/recruitment/data/recruitment_flight_repository.dart',
    );
    final models = source(
      'lib/features/recruitment/models/recruitment_flight_models.dart',
    );

    expect(repository, contains('class RecruitmentFlightTicketUpload'));
    expect(repository, contains('fetchFlightTickets'));
    expect(repository, contains(".from('recruitment_flight_tickets')"));
    expect(repository, contains('ticketUploads'));
    expect(repository, contains('maxTicketsPerFlight = 10'));
    expect(repository, contains('createFlightTicketUrl'));
    expect(models, contains('class RecruitmentFlightTicket'));
    expect(models, contains('final List<RecruitmentFlightTicket> tickets'));
  });

  test('flight editor uses multi select and shows every attachment', () {
    final screen = source(
      'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart',
    );

    expect(screen, contains('openFiles('));
    expect(screen, contains('pendingTickets'));
    expect(screen, contains("'Купленные билеты'"));
    expect(screen, contains("'Добавить ещё билеты'"));
    expect(screen, contains('openTickets('));
    expect(screen, contains('Билеты ('));
    expect(screen, contains('maxTicketsPerFlight'));
  });
}
