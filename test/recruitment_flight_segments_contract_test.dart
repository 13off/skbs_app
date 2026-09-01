import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/recruitment/models/recruitment_flight_models.dart';

void main() {
  test('legacy flight becomes one route segment', () {
    final flight = RecruitmentFlight.fromMap(<String, dynamic>{
      'id': 'flight-1',
      'company_id': 'company-1',
      'departure_at': '2026-09-10T07:00:00Z',
      'arrival_at': '2026-09-10T09:00:00Z',
      'origin': 'Тюмень',
      'destination': 'Москва',
      'flight_number': 'SU 100',
      'created_at': '2026-09-01T00:00:00Z',
    });
    expect(flight.segments, hasLength(1));
    expect(flight.routeTitle, 'Тюмень → Москва');
  });

  test('multi-leg route uses ordered segment chain', () {
    final flight = RecruitmentFlight.fromMap(<String, dynamic>{
      'id': 'flight-2',
      'company_id': 'company-1',
      'departure_at': '2026-09-10T07:00:00Z',
      'origin': 'Тюмень',
      'destination': 'Талакан',
      'flight_number': 'SU 100',
      'segments': <Map<String, dynamic>>[
        <String, dynamic>{
          'origin': 'Тюмень',
          'destination': 'Москва',
          'flight_number': 'SU 100',
          'departure_at': '2026-09-10T07:00:00Z',
          'arrival_at': '2026-09-10T09:00:00Z',
        },
        <String, dynamic>{
          'origin': 'Москва',
          'destination': 'Талакан',
          'flight_number': 'IO 200',
          'departure_at': '2026-09-10T12:00:00Z',
          'arrival_at': '2026-09-10T18:00:00Z',
        },
      ],
      'created_at': '2026-09-01T00:00:00Z',
    });
    expect(flight.segments, hasLength(2));
    expect(flight.destination, 'Талакан');
    expect(flight.routeTitle, 'Тюмень → Москва → Талакан');
  });

  test('editor exposes add flight action', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart',
    ).readAsStringSync();
    expect(source, contains("label: const Text('Добавить рейс')"));
    expect(source, contains('segments: segmentValues'));
  });

  test('migration stores route segments', () {
    final source = File(
      'supabase/migrations/20260901143000_recruitment_flight_segments.sql',
    ).readAsStringSync();
    expect(source, contains('segments jsonb'));
  });
}
