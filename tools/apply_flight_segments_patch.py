from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'missing anchor: {label}')
    return text.replace(old, new, 1)


def replace_range(text: str, start_marker: str, end_marker: str, replacement: str, label: str, start_at: int = 0) -> str:
    start = text.find(start_marker, start_at)
    if start < 0:
        raise RuntimeError(f'missing start: {label}')
    end = text.find(end_marker, start + len(start_marker))
    if end < 0:
        raise RuntimeError(f'missing end: {label}')
    return text[:start] + replacement + text[end:]


# Model
path = Path('lib/features/recruitment/models/recruitment_flight_models.dart')
text = path.read_text()
segment_class = '''class RecruitmentFlightSegment {
  final String origin;
  final String destination;
  final String flightNumber;
  final DateTime departureAt;
  final DateTime? arrivalAt;

  const RecruitmentFlightSegment({
    required this.origin,
    required this.destination,
    required this.flightNumber,
    required this.departureAt,
    required this.arrivalAt,
  });

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'origin': origin.trim(),
    'destination': destination.trim(),
    'flight_number': flightNumber.trim().toUpperCase(),
    'departure_at': departureAt.toUtc().toIso8601String(),
    'arrival_at': arrivalAt?.toUtc().toIso8601String(),
  };

  factory RecruitmentFlightSegment.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
    DateTime? optionalDate(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    return RecruitmentFlightSegment(
      origin: map['origin']?.toString() ?? '',
      destination: map['destination']?.toString() ?? '',
      flightNumber: map['flight_number']?.toString() ?? '',
      departureAt: parseDate(map['departure_at']),
      arrivalAt: optionalDate(map['arrival_at']),
    );
  }
}

'''
text = replace_once(text, 'class RecruitmentFlight {\n', segment_class + 'class RecruitmentFlight {\n', 'segment class')
text = replace_once(text, '  final String flightNumber;\n  final String status;', '  final String flightNumber;\n  final List<RecruitmentFlightSegment> segments;\n  final String status;', 'segments field')
text = replace_once(text, '    required this.flightNumber,\n    required this.status,', '    required this.flightNumber,\n    this.segments = const <RecruitmentFlightSegment>[],\n    required this.status,', 'segments constructor')
route_start = '  String get routeTitle {'
route_end = '\n\n  String get statusTitle'
new_route = '''  String get routeTitle {
    final routeSegments = segments
        .where((segment) =>
            segment.origin.trim().isNotEmpty ||
            segment.destination.trim().isNotEmpty)
        .toList(growable: false);
    if (routeSegments.isNotEmpty) {
      final stops = <String>[];
      void addStop(String value) {
        final clean = value.trim();
        if (clean.isNotEmpty && (stops.isEmpty || stops.last != clean)) {
          stops.add(clean);
        }
      }

      addStop(routeSegments.first.origin);
      for (final segment in routeSegments) {
        addStop(segment.destination);
      }
      if (stops.isNotEmpty) return stops.join(' → ');
    }
    final cleanOrigin = origin.trim();
    final cleanDestination = destination.trim();
    if (cleanOrigin.isEmpty && cleanDestination.isEmpty) {
      return 'Маршрут не указан';
    }
    if (cleanOrigin.isEmpty) return cleanDestination;
    if (cleanDestination.isEmpty) return cleanOrigin;
    return '$cleanOrigin → $cleanDestination';
  }'''
text = replace_range(text, route_start, route_end, new_route, 'route title')
parse_anchor = "    final createdAt = parseDate(map['created_at']);\n"
parse_block = '''    final createdAt = parseDate(map['created_at']);
    final legacyDepartureAt = parseDate(map['departure_at']);
    final legacyArrivalAt = optionalDate(map['arrival_at']);
    final rawSegments = map['segments'];
    final parsedSegments = rawSegments is List
        ? rawSegments
            .whereType<Map>()
            .map(
              (item) => RecruitmentFlightSegment.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <RecruitmentFlightSegment>[];
    final segments = parsedSegments.isNotEmpty
        ? parsedSegments
        : <RecruitmentFlightSegment>[
            RecruitmentFlightSegment(
              origin: map['origin']?.toString() ?? '',
              destination: map['destination']?.toString() ?? '',
              flightNumber: map['flight_number']?.toString() ?? '',
              departureAt: legacyDepartureAt,
              arrivalAt: legacyArrivalAt,
            ),
          ];
'''
text = replace_once(text, parse_anchor, parse_block, 'segments parsing')
text = replace_once(
    text,
    "      departureAt: parseDate(map['departure_at']),\n      arrivalAt: optionalDate(map['arrival_at']),\n      origin: map['origin']?.toString() ?? '',\n      destination: map['destination']?.toString() ?? '',\n      flightNumber: map['flight_number']?.toString() ?? '',",
    "      departureAt: segments.first.departureAt,\n      arrivalAt: segments.last.arrivalAt,\n      origin: segments.first.origin,\n      destination: segments.last.destination,\n      flightNumber: segments.first.flightNumber,\n      segments: List<RecruitmentFlightSegment>.unmodifiable(segments),",
    'mapped route fields',
)
path.write_text(text)

# Repository
path = Path('lib/features/recruitment/data/recruitment_flight_repository.dart')
text = path.read_text()
text = replace_once(text, "    String flightNumber = '',\n    List<RecruitmentFlightReminder> reminders =", "    String flightNumber = '',\n    List<RecruitmentFlightSegment> segments = const <RecruitmentFlightSegment>[],\n    List<RecruitmentFlightReminder> reminders =", 'repo parameter')
validation_start = "    if (origin.trim().isEmpty || destination.trim().isEmpty) {"
validation_end = '\n\n    final reminderKeys = <String>{};'
new_validation = '''    final normalizedSegments = segments.isEmpty
        ? <RecruitmentFlightSegment>[
            RecruitmentFlightSegment(
              origin: origin.trim(),
              destination: destination.trim(),
              flightNumber: flightNumber.trim(),
              departureAt: departureAt,
              arrivalAt: arrivalAt,
            ),
          ]
        : List<RecruitmentFlightSegment>.from(segments);
    for (var index = 0; index < normalizedSegments.length; index++) {
      final segment = normalizedSegments[index];
      if (segment.origin.trim().isEmpty || segment.destination.trim().isEmpty) {
        throw Exception('Укажите откуда и куда для рейса ${index + 1}');
      }
      if (segment.departureAt.isBefore(
        DateTime.now().subtract(const Duration(days: 1)),
      )) {
        throw Exception('Дата вылета рейса ${index + 1} уже прошла');
      }
      if (segment.arrivalAt != null &&
          !segment.arrivalAt!.isAfter(segment.departureAt)) {
        throw Exception('Прибытие рейса ${index + 1} должно быть позже вылета');
      }
      if (index > 0) {
        final previous = normalizedSegments[index - 1];
        final previousEnd = previous.arrivalAt ?? previous.departureAt;
        if (!segment.departureAt.isAfter(previousEnd)) {
          throw Exception('Следующий рейс должен вылетать позже предыдущего');
        }
      }
    }
    final firstSegment = normalizedSegments.first;
    final lastSegment = normalizedSegments.last;'''
text = replace_range(text, validation_start, validation_end, new_validation, 'repo validation')
text = replace_once(text, "reminder.eventKind == 'arrival' && arrivalAt == null", "reminder.eventKind == 'arrival' && lastSegment.arrivalAt == null", 'arrival reminder')
text = replace_once(
    text,
    "      'departure_at': departureAt.toUtc().toIso8601String(),\n      'arrival_at': arrivalAt?.toUtc().toIso8601String(),\n      'origin': origin.trim(),\n      'destination': destination.trim(),\n      'flight_number': flightNumber.trim().toUpperCase(),",
    "      'departure_at': firstSegment.departureAt.toUtc().toIso8601String(),\n      'arrival_at': lastSegment.arrivalAt?.toUtc().toIso8601String(),\n      'origin': firstSegment.origin.trim(),\n      'destination': lastSegment.destination.trim(),\n      'flight_number': firstSegment.flightNumber.trim().toUpperCase(),\n      'segments': normalizedSegments.map((segment) => segment.toPayload()).toList(),",
    'repo payload',
)
path.write_text(text)

# Editor
path = Path('lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart')
text = path.read_text()
draft_class = '''class _FlightSegmentDraft {
  final TextEditingController originController;
  final TextEditingController destinationController;
  final TextEditingController flightNumberController;
  DateTime departureAt;
  DateTime? arrivalAt;

  _FlightSegmentDraft({
    required String origin,
    required String destination,
    required String flightNumber,
    required this.departureAt,
    required this.arrivalAt,
  })  : originController = TextEditingController(text: origin),
        destinationController = TextEditingController(text: destination),
        flightNumberController = TextEditingController(text: flightNumber);

  factory _FlightSegmentDraft.fromSegment(RecruitmentFlightSegment segment) =>
      _FlightSegmentDraft(
        origin: segment.origin,
        destination: segment.destination,
        flightNumber: segment.flightNumber,
        departureAt: segment.departureAt,
        arrivalAt: segment.arrivalAt,
      );

  RecruitmentFlightSegment toSegment() => RecruitmentFlightSegment(
        origin: originController.text.trim(),
        destination: destinationController.text.trim(),
        flightNumber: flightNumberController.text.trim(),
        departureAt: departureAt,
        arrivalAt: arrivalAt,
      );

  void dispose() {
    originController.dispose();
    destinationController.dispose();
    flightNumberController.dispose();
  }
}

'''
text = replace_once(text, 'class RecruitmentFlightEditorScreen extends StatefulWidget {\n', draft_class + 'class RecruitmentFlightEditorScreen extends StatefulWidget {\n', 'draft editor class')
text = replace_once(text, '''  RecruitmentFlightCandidate? candidate;
  late DateTime departureAt;
  DateTime? arrivalAt;
  late final TextEditingController originController;
  late final TextEditingController destinationController;
  late final TextEditingController flightNumberController;
  late final TextEditingController notesController;
''', '''  RecruitmentFlightCandidate? candidate;
  late final List<_FlightSegmentDraft> flightSegments;
  late final TextEditingController notesController;
''', 'editor fields')
state_start = text.index('class _RecruitmentFlightEditorScreenState')
init_start = text.index('    departureAt =\n', state_start)
init_end_marker = "    notesController = TextEditingController(text: entry?.flight.notes ?? '');"
init_end = text.index(init_end_marker, init_start) + len(init_end_marker)
new_init = '''    final storedSegments =
        entry?.flight.segments ?? const <RecruitmentFlightSegment>[];
    if (storedSegments.isNotEmpty) {
      flightSegments = storedSegments
          .map(_FlightSegmentDraft.fromSegment)
          .toList(growable: true);
    } else if (entry != null) {
      flightSegments = <_FlightSegmentDraft>[
        _FlightSegmentDraft(
          origin: entry.flight.origin,
          destination: entry.flight.destination,
          flightNumber: entry.flight.flightNumber,
          departureAt: entry.flight.departureAt,
          arrivalAt: entry.flight.arrivalAt,
        ),
      ];
    } else {
      flightSegments = <_FlightSegmentDraft>[
        _FlightSegmentDraft(
          origin: '',
          destination: '',
          flightNumber: '',
          departureAt: DateTime.now().add(const Duration(days: 1, hours: 3)),
          arrivalAt: null,
        ),
      ];
    }
    notesController = TextEditingController(text: entry?.flight.notes ?? '');'''
text = text[:init_start] + new_init + text[init_end:]
text = replace_once(text, '''    originController.dispose();
    destinationController.dispose();
    flightNumberController.dispose();
    notesController.dispose();
''', '''    for (final segment in flightSegments) {
      segment.dispose();
    }
    notesController.dispose();
''', 'editor dispose')
choose_start = '  Future<void> chooseDeparture() async {'
choose_end = '\n\n  Future<void> addReminder() async {'
new_choose = '''  Future<void> chooseDeparture(int index) async {
    final segment = flightSegments[index];
    final value = await chooseDateTime(segment.departureAt);
    if (value != null && mounted) {
      setState(() => segment.departureAt = value);
    }
  }

  Future<void> chooseArrival(int index) async {
    final segment = flightSegments[index];
    final value = await chooseDateTime(
      segment.arrivalAt ?? segment.departureAt.add(const Duration(hours: 3)),
    );
    if (value != null && mounted) {
      setState(() => segment.arrivalAt = value);
    }
  }

  void addFlightSegment() {
    final previous = flightSegments.last;
    final suggestedDeparture = (previous.arrivalAt ?? previous.departureAt)
        .add(const Duration(hours: 2));
    setState(() {
      flightSegments.add(
        _FlightSegmentDraft(
          origin: previous.destinationController.text.trim(),
          destination: '',
          flightNumber: '',
          departureAt: suggestedDeparture,
          arrivalAt: null,
        ),
      );
    });
  }

  void removeFlightSegment(int index) {
    if (index <= 0 || index >= flightSegments.length) return;
    final removed = flightSegments.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Widget buildFlightSegmentCard(int index) {
    final segment = flightSegments[index];
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  index == 0 ? 'Рейс 1' : 'Рейс ${index + 1} · пересадка',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              if (index > 0)
                IconButton(
                  tooltip: 'Удалить рейс',
                  onPressed: saving ? null : () => removeFlightSegment(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final originField = TextField(
                controller: segment.originController,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Откуда',
                  hintText: 'Москва',
                  prefixIcon: Icon(Icons.flight_takeoff_outlined),
                ),
              );
              final destinationField = TextField(
                controller: segment.destinationController,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Куда',
                  hintText: 'Мурманск',
                  prefixIcon: Icon(Icons.flight_land_outlined),
                ),
                onChanged: (value) {
                  if (index + 1 < flightSegments.length &&
                      flightSegments[index + 1]
                          .originController
                          .text
                          .trim()
                          .isEmpty) {
                    flightSegments[index + 1].originController.text = value.trim();
                  }
                },
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    originField,
                    const SizedBox(height: 10),
                    destinationField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: originField),
                  const SizedBox(width: 10),
                  Expanded(child: destinationField),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: segment.flightNumberController,
            enabled: !saving,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Номер рейса',
              hintText: 'SU 1320',
              prefixIcon: Icon(Icons.airplane_ticket_outlined),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving ? null : () => chooseDeparture(index),
            icon: const Icon(Icons.event_outlined),
            label: Text('Вылет: ${dateTimeText(segment.departureAt)}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: saving ? null : () => chooseArrival(index),
            icon: const Icon(Icons.schedule_outlined),
            label: Text(
              segment.arrivalAt == null
                  ? 'Указать время прибытия'
                  : 'Прибытие: ${dateTimeText(segment.arrivalAt!)}',
            ),
          ),
          if (segment.arrivalAt != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: saving
                    ? null
                    : () => setState(() => segment.arrivalAt = null),
                child: const Text('Убрать время прибытия'),
              ),
            ),
        ],
      ),
    );
  }'''
text = replace_range(text, choose_start, choose_end, new_choose, 'segment methods', state_start)
text = replace_once(text, "    if (eventKind == 'arrival' && arrivalAt == null) {", "    final tripArrivalAt = flightSegments.last.arrivalAt;\n    if (eventKind == 'arrival' && tripArrivalAt == null) {", 'reminder arrival check')
text = replace_once(text, "const SnackBar(content: Text('Сначала укажите время прибытия рейса'))", "const SnackBar(content: Text('Сначала укажите время прибытия последнего рейса'))", 'reminder message')
text = replace_once(text, "    final eventAt = eventKind == 'arrival' ? arrivalAt : departureAt;", "    final eventAt = eventKind == 'arrival'\n        ? tripArrivalAt\n        : flightSegments.first.departureAt;", 'reminder event time')
text = replace_once(text, '    setState(() => saving = true);\n    try {\n      await RecruitmentFlightRepository.saveFlight(', '''    final segmentValues = flightSegments
        .map((segment) => segment.toSegment())
        .toList(growable: false);
    final firstSegment = segmentValues.first;
    final lastSegment = segmentValues.last;
    setState(() => saving = true);
    try {
      await RecruitmentFlightRepository.saveFlight(''', 'save preparation')
text = replace_once(text, '''        departureAt: departureAt,
        arrivalAt: arrivalAt,
        origin: originController.text,
        destination: destinationController.text,
        flightNumber: flightNumberController.text,
''', '''        departureAt: firstSegment.departureAt,
        arrivalAt: lastSegment.arrivalAt,
        origin: firstSegment.origin,
        destination: lastSegment.destination,
        flightNumber: firstSegment.flightNumber,
        segments: segmentValues,
''', 'save args')
route_start = text.find("          Row(\n            children: [\n              Expanded(\n                child: TextField(\n                  controller: originController,", state_start)
if route_start < 0:
    raise RuntimeError('missing route ui start')
route_end = text.find('          PremiumWorkCard(\n            radius: 22,', route_start)
if route_end < 0:
    raise RuntimeError('missing route ui end')
route_ui = '''          for (var index = 0; index < flightSegments.length; index++) ...[
            buildFlightSegmentCard(index),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: saving ? null : addFlightSegment,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить рейс'),
          ),
          const SizedBox(height: 12),
'''
text = text[:route_start] + route_ui + text[route_end:]
path.write_text(text)

# Test
Path('test/recruitment_flight_segments_contract_test.dart').write_text('''import 'dart:io';

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
''')
