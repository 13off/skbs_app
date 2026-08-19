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
  final int offsetMinutes;
  final DateTime? sentAt;

  const RecruitmentFlightReminder({
    this.id = '',
    this.companyId = '',
    this.flightId = '',
    required this.eventKind,
    required this.offsetMinutes,
    this.sentAt,
  });

  bool get isArrival => eventKind == 'arrival';
  bool get isSent => sentAt != null;

  DateTime? eventAt(RecruitmentFlight flight) =>
      isArrival ? flight.arrivalAt : flight.departureAt;

  DateTime? triggerAt(RecruitmentFlight flight) =>
      eventAt(flight)?.subtract(Duration(minutes: offsetMinutes));

  String get label {
    final event = isArrival ? 'прибытия' : 'отправления';
    if (offsetMinutes == 0) return 'В момент $event';
    return 'За ${_offsetTitle(offsetMinutes)} до $event';
  }

  static String _offsetTitle(int minutes) {
    if (minutes < 60) return '$minutes мин';
    if (minutes % 1440 == 0) {
      final days = minutes ~/ 1440;
      return '$days ${days == 1 ? 'день' : days < 5 ? 'дня' : 'дней'}';
    }
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours ч';
    return '$hours ч $rest мин';
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'event_kind': eventKind,
    'offset_minutes': offsetMinutes,
  };

  factory RecruitmentFlightReminder.fromMap(Map<String, dynamic> map) {
    DateTime? optionalDate(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    final rawOffset = map['offset_minutes'];
    final offset = switch (rawOffset) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(rawOffset?.toString() ?? '') ?? 0,
    };
    return RecruitmentFlightReminder(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      flightId: map['flight_id']?.toString() ?? '',
      eventKind: map['event_kind']?.toString() == 'arrival'
          ? 'arrival'
          : 'departure',
      offsetMinutes: offset,
      sentAt: optionalDate(map['sent_at']),
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
    final cleanOrigin = origin.trim();
    final cleanDestination = destination.trim();
    if (cleanOrigin.isEmpty && cleanDestination.isEmpty) return 'Маршрут не указан';
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
    return RecruitmentFlight(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      departureAt: parseDate(map['departure_at']),
      arrivalAt: optionalDate(map['arrival_at']),
      origin: map['origin']?.toString() ?? '',
      destination: map['destination']?.toString() ?? '',
      flightNumber: map['flight_number']?.toString() ?? '',
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
