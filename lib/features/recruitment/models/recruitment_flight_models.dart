class RecruitmentFlightCandidate {
  final String applicationId;
  final String companyId;
  final String employeeId;
  final String fullName;
  final String phone;
  final String positionTitle;
  final String objectId;
  final String objectName;
  final String source;
  final String sourceUserId;
  final String sourceChatId;

  const RecruitmentFlightCandidate({
    required this.applicationId,
    required this.companyId,
    required this.employeeId,
    required this.fullName,
    required this.phone,
    required this.positionTitle,
    required this.objectId,
    required this.objectName,
    required this.source,
    required this.sourceUserId,
    required this.sourceChatId,
  });

  bool get hasEmployee => employeeId.trim().isNotEmpty;
  bool get canMessageInMax =>
      source == 'max' && sourceUserId.trim().isNotEmpty;
  bool get canMessageInTelegram =>
      source == 'telegram' && sourceChatId.trim().isNotEmpty;
  bool get canMessageInBot => canMessageInMax || canMessageInTelegram;

  factory RecruitmentFlightCandidate.fromMap(Map<String, dynamic> map) {
    final objectValue = map['objects'];
    final object = objectValue is Map
        ? Map<String, dynamic>.from(objectValue)
        : const <String, dynamic>{};
    return RecruitmentFlightCandidate(
      applicationId: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      positionTitle: map['position_title']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: object['name']?.toString() ?? '',
      source: map['source']?.toString() ?? 'manual',
      sourceUserId: map['external_user_id']?.toString() ?? '',
      sourceChatId: map['external_chat_id']?.toString() ?? '',
    );
  }
}

class RecruitmentFlightTicket {
  final String id;
  final String companyId;
  final String flightId;
  final String bucket;
  final String path;
  final String originalName;
  final String mimeType;
  final int? sizeBytes;
  final DateTime createdAt;

  const RecruitmentFlightTicket({
    required this.id,
    required this.companyId,
    required this.flightId,
    required this.bucket,
    required this.path,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory RecruitmentFlightTicket.fromMap(Map<String, dynamic> map) {
    int? optionalInt(dynamic value) {
      return switch (value) {
        int number => number,
        num number => number.toInt(),
        _ => int.tryParse(value?.toString() ?? ''),
      };
    }

    return RecruitmentFlightTicket(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      flightId: map['flight_id']?.toString() ?? '',
      bucket: map['bucket']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      originalName: map['original_name']?.toString() ?? '',
      mimeType: map['mime_type']?.toString() ?? '',
      sizeBytes: optionalInt(map['size_bytes']),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  factory RecruitmentFlightTicket.fromLegacy(RecruitmentFlight flight) {
    return RecruitmentFlightTicket(
      id: 'legacy:${flight.id}',
      companyId: flight.companyId,
      flightId: flight.id,
      bucket: flight.ticketBucket,
      path: flight.ticketPath,
      originalName: flight.ticketOriginalName,
      mimeType: flight.ticketMimeType,
      sizeBytes: flight.ticketSizeBytes,
      createdAt: flight.createdAt,
    );
  }
}

class RecruitmentFlightReminder {
  final String id;
  final String companyId;
  final String flightId;
  final String eventKind;
  final String title;
  final DateTime remindAt;
  final DateTime? sentAt;

  const RecruitmentFlightReminder({
    this.id = '',
    this.companyId = '',
    this.flightId = '',
    this.eventKind = 'departure',
    this.title = '',
    required this.remindAt,
    this.sentAt,
  });

  bool get isSent => sentAt != null;
  bool get isArrival => eventKind == 'arrival';
  String get eventTitle => isArrival ? 'Прибытие' : 'Отправление';
  String get displayTitle => title.trim().isEmpty ? eventTitle : title.trim();

  String get label {
    final local = remindAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} · $hour:$minute';
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'event_kind': eventKind,
    'reminder_title': title.trim(),
    'remind_at': remindAt.toUtc().toIso8601String(),
  };

  factory RecruitmentFlightReminder.fromMap(Map<String, dynamic> map) {
    DateTime? optionalDate(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    final rawEvent = map['event_kind']?.toString().trim() ?? '';
    return RecruitmentFlightReminder(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      flightId: map['flight_id']?.toString() ?? '',
      eventKind: rawEvent == 'arrival' ? 'arrival' : 'departure',
      title: map['reminder_title']?.toString() ?? '',
      remindAt:
          optionalDate(map['remind_at']) ??
          optionalDate(map['created_at']) ??
          DateTime.now(),
      sentAt: optionalDate(map['sent_at']),
    );
  }
}

class RecruitmentFlightSegment {
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

class RecruitmentFlight {
  final String id;
  final String companyId;
  final String applicationId;
  final String employeeId;
  final String objectId;
  final DateTime departureAt;
  final DateTime? arrivalAt;
  final String origin;
  final String destination;
  final String flightNumber;
  final List<RecruitmentFlightSegment> segments;
  final String status;
  final bool remindDayBefore;
  final bool remindThreeHours;
  final DateTime? dayBeforeSentAt;
  final DateTime? threeHoursSentAt;
  final DateTime? lastManualReminderAt;
  final String ticketBucket;
  final String ticketPath;
  final String ticketOriginalName;
  final String ticketMimeType;
  final int? ticketSizeBytes;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecruitmentFlight({
    required this.id,
    required this.companyId,
    required this.applicationId,
    required this.employeeId,
    required this.objectId,
    required this.departureAt,
    required this.arrivalAt,
    required this.origin,
    required this.destination,
    required this.flightNumber,
    this.segments = const <RecruitmentFlightSegment>[],
    required this.status,
    required this.remindDayBefore,
    required this.remindThreeHours,
    required this.dayBeforeSentAt,
    required this.threeHoursSentAt,
    required this.lastManualReminderAt,
    required this.ticketBucket,
    required this.ticketPath,
    required this.ticketOriginalName,
    required this.ticketMimeType,
    required this.ticketSizeBytes,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasTicket => ticketBucket.isNotEmpty && ticketPath.isNotEmpty;
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'arrived';
  bool get isUpcoming =>
      !isCancelled && departureAt.isAfter(DateTime.now());

  String get routeTitle {
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
  }

  String get statusTitle => switch (status) {
    'checked_in' => 'Регистрация пройдена',
    'departed' => 'Вылетел',
    'arrived' => 'Прибыл',
    'cancelled' => 'Отменён',
    _ => 'Запланирован',
  };

  factory RecruitmentFlight.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
          fallback ??
          DateTime.now();
    }

    DateTime? optionalDate(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    int? optionalInt(dynamic value) {
      return switch (value) {
        int number => number,
        num number => number.toInt(),
        _ => int.tryParse(value?.toString() ?? ''),
      };
    }

    final createdAt = parseDate(map['created_at']);
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
    return RecruitmentFlight(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      departureAt: segments.first.departureAt,
      arrivalAt: segments.last.arrivalAt,
      origin: segments.first.origin,
      destination: segments.last.destination,
      flightNumber: segments.first.flightNumber,
      segments: List<RecruitmentFlightSegment>.unmodifiable(segments),
      status: map['status']?.toString() ?? 'scheduled',
      remindDayBefore: map['remind_day_before'] != false,
      remindThreeHours: map['remind_three_hours'] != false,
      dayBeforeSentAt: optionalDate(map['day_before_sent_at']),
      threeHoursSentAt: optionalDate(map['three_hours_sent_at']),
      lastManualReminderAt: optionalDate(map['last_manual_reminder_at']),
      ticketBucket: map['ticket_bucket']?.toString() ?? '',
      ticketPath: map['ticket_path']?.toString() ?? '',
      ticketOriginalName: map['ticket_original_name']?.toString() ?? '',
      ticketMimeType: map['ticket_mime_type']?.toString() ?? '',
      ticketSizeBytes: optionalInt(map['ticket_size_bytes']),
      notes: map['notes']?.toString() ?? '',
      createdAt: createdAt,
      updatedAt: parseDate(map['updated_at'], fallback: createdAt),
    );
  }
}

class RecruitmentFlightEntry {
  final RecruitmentFlight flight;
  final RecruitmentFlightCandidate candidate;
  final List<RecruitmentFlightTicket> tickets;
  final List<RecruitmentFlightReminder> reminders;

  const RecruitmentFlightEntry({
    required this.flight,
    required this.candidate,
    this.tickets = const <RecruitmentFlightTicket>[],
    this.reminders = const <RecruitmentFlightReminder>[],
  });
}

class RecruitmentFlightCalendarData {
  final List<RecruitmentFlightCandidate> candidates;
  final List<RecruitmentFlightEntry> flights;

  const RecruitmentFlightCalendarData({
    required this.candidates,
    required this.flights,
  });
}

class RecruitmentFlightReminderResult {
  final String notificationId;
  final String applicationId;
  final String message;
  final bool hasAppRecipient;

  const RecruitmentFlightReminderResult({
    required this.notificationId,
    required this.applicationId,
    required this.message,
    required this.hasAppRecipient,
  });

  factory RecruitmentFlightReminderResult.fromMap(Map<String, dynamic> map) {
    return RecruitmentFlightReminderResult(
      notificationId: map['notification_id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      hasAppRecipient: map['has_app_recipient'] == true,
    );
  }
}
