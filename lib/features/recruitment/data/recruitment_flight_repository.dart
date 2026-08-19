import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../../../services/push_notification_service.dart';
import '../models/recruitment_flight_models.dart';
import 'recruitment_repository.dart';

class RecruitmentFlightTicketUpload {
  final String fileName;
  final Uint8List bytes;

  const RecruitmentFlightTicketUpload({
    required this.fileName,
    required this.bytes,
  });
}

abstract final class RecruitmentFlightRepository {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String ticketBucket = 'recruitment-documents';
  static const int maxTicketsPerFlight = 10;
  static const int maxTicketBytes = 20 * 1024 * 1024;
  static const int maxTotalTicketBytes = 100 * 1024 * 1024;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static String _safeFileName(String value) {
    final clean = value
        .trim()
        .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return clean.isEmpty ? 'ticket.pdf' : clean;
  }

  static String _mimeType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  static void _notify(String flightId) {
    AppDataSync.notifyLocal(
      const <AppDataDomain>{
        AppDataDomain.recruitment,
        AppDataDomain.notifications,
      },
      context: <String, dynamic>{
        'table': 'recruitment_flights',
        'entity_id': flightId,
      },
    );
  }

  static Future<List<RecruitmentFlightCandidate>> fetchCandidates({
    required String companyId,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <RecruitmentFlightCandidate>[];
    final rows = await _client
        .from('recruitment_applications')
        .select(
          'id, company_id, employee_id, full_name, phone, position_title, '
          'object_id, source, external_user_id, external_chat_id, objects(name)',
        )
        .eq('company_id', cleanCompanyId)
        .isFilter('archived_at', null)
        .neq('status', 'rejected')
        .order('full_name');
    return rows
        .map<RecruitmentFlightCandidate>(
          (row) => RecruitmentFlightCandidate.fromMap(_map(row)),
        )
        .where(
          (candidate) =>
              candidate.applicationId.isNotEmpty &&
              candidate.fullName.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  static Future<List<RecruitmentFlight>> fetchFlights({
    required String companyId,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <RecruitmentFlight>[];
    final rows = await _client
        .from('recruitment_flights')
        .select()
        .eq('company_id', cleanCompanyId)
        .order('departure_at', ascending: true)
        .limit(1000);
    return rows
        .map<RecruitmentFlight>(
          (row) => RecruitmentFlight.fromMap(_map(row)),
        )
        .where((flight) => flight.id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<RecruitmentFlightReminder>> fetchFlightReminders({
    required String companyId,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <RecruitmentFlightReminder>[];
    final rows = await _client
        .from('recruitment_flight_reminders')
        .select()
        .eq('company_id', cleanCompanyId)
        .order('created_at', ascending: true)
        .limit(10000);
    return rows
        .map<RecruitmentFlightReminder>(
          (row) => RecruitmentFlightReminder.fromMap(_map(row)),
        )
        .where((reminder) => reminder.flightId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<RecruitmentFlightTicket>> fetchFlightTickets({
    required String companyId,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <RecruitmentFlightTicket>[];
    final rows = await _client
        .from('recruitment_flight_tickets')
        .select()
        .eq('company_id', cleanCompanyId)
        .order('created_at', ascending: true)
        .order('id', ascending: true)
        .limit(10000);
    return rows
        .map<RecruitmentFlightTicket>(
          (row) => RecruitmentFlightTicket.fromMap(_map(row)),
        )
        .where((ticket) => ticket.id.isNotEmpty && ticket.flightId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<RecruitmentFlightCalendarData> fetchCalendar({
    required String companyId,
    bool dispatchReminders = true,
  }) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      fetchCandidates(companyId: companyId),
      fetchFlights(companyId: companyId),
      fetchFlightTickets(companyId: companyId),
      fetchFlightReminders(companyId: companyId),
    ]);
    final candidates = results[0] as List<RecruitmentFlightCandidate>;
    final flights = results[1] as List<RecruitmentFlight>;
    final tickets = results[2] as List<RecruitmentFlightTicket>;
    final reminders = results[3] as List<RecruitmentFlightReminder>;
    final candidatesById = <String, RecruitmentFlightCandidate>{
      for (final candidate in candidates) candidate.applicationId: candidate,
    };
    final ticketsByFlight = <String, List<RecruitmentFlightTicket>>{};
    for (final ticket in tickets) {
      ticketsByFlight
          .putIfAbsent(ticket.flightId, () => <RecruitmentFlightTicket>[])
          .add(ticket);
    }
    final remindersByFlight = <String, List<RecruitmentFlightReminder>>{};
    for (final reminder in reminders) {
      remindersByFlight
          .putIfAbsent(reminder.flightId, () => <RecruitmentFlightReminder>[])
          .add(reminder);
    }
    final entries = flights
        .map((flight) {
          final candidate = candidatesById[flight.applicationId];
          if (candidate == null) return null;
          final attachments = <RecruitmentFlightTicket>[
            ...?ticketsByFlight[flight.id],
          ];
          if (attachments.isEmpty && flight.hasTicket) {
            attachments.add(RecruitmentFlightTicket.fromLegacy(flight));
          }
          return RecruitmentFlightEntry(
            flight: flight,
            candidate: candidate,
            tickets: List<RecruitmentFlightTicket>.unmodifiable(attachments),
            reminders: List<RecruitmentFlightReminder>.unmodifiable(
              remindersByFlight[flight.id] ?? const <RecruitmentFlightReminder>[],
            ),
          );
        })
        .whereType<RecruitmentFlightEntry>()
        .toList(growable: false);
    if (dispatchReminders) {
      unawaited(
        dispatchDueReminders(candidates: candidates).catchError((_) {}),
      );
    }
    return RecruitmentFlightCalendarData(
      candidates: candidates,
      flights: entries,
    );
  }

  static Future<Map<String, dynamic>> _uploadTicket({
    required String companyId,
    required String applicationId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) throw Exception('Файл билета пустой');
    if (bytes.length > maxTicketBytes) {
      throw Exception('Файл билета должен быть меньше 20 МБ');
    }
    final safeName = _safeFileName(fileName);
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final path = '$companyId/$applicationId/tickets/${stamp}_$safeName';
    final mimeType = _mimeType(safeName);
    await _client.storage.from(ticketBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );
    return <String, dynamic>{
      'ticket_bucket': ticketBucket,
      'ticket_path': path,
      'ticket_original_name': safeName,
      'ticket_mime_type': mimeType,
      'ticket_size_bytes': bytes.length,
    };
  }

  static Future<RecruitmentFlight> saveFlight({
    String flightId = '',
    required RecruitmentFlightCandidate candidate,
    required DateTime departureAt,
    DateTime? arrivalAt,
    required String origin,
    required String destination,
    String flightNumber = '',
    List<RecruitmentFlightReminder> reminders =
        const <RecruitmentFlightReminder>[],
    String notes = '',
    Uint8List? ticketBytes,
    String ticketFileName = '',
    List<RecruitmentFlightTicketUpload> ticketUploads =
        const <RecruitmentFlightTicketUpload>[],
    RecruitmentFlight? existing,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Нет активной Auth-сессии');
    if (candidate.applicationId.trim().isEmpty) {
      throw Exception('Выберите сотрудника');
    }
    if (origin.trim().isEmpty || destination.trim().isEmpty) {
      throw Exception('Укажите город вылета и назначения');
    }
    if (departureAt.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      throw Exception('Дата вылета уже прошла');
    }
    if (arrivalAt != null && !arrivalAt.isAfter(departureAt)) {
      throw Exception('Прибытие должно быть позже вылета');
    }

    final reminderKeys = <String>{};
    for (final reminder in reminders) {
      if (reminder.eventKind != 'departure' && reminder.eventKind != 'arrival') {
        throw Exception('Некорректное событие уведомления');
      }
      if (reminder.offsetMinutes < 0 || reminder.offsetMinutes > 43200) {
        throw Exception('Уведомление можно поставить не более чем за 30 дней');
      }
      final key = '${reminder.eventKind}:${reminder.offsetMinutes}';
      if (!reminderKeys.add(key)) {
        throw Exception('Такое уведомление уже добавлено');
      }
      final eventAt = reminder.eventKind == 'arrival' ? arrivalAt : departureAt;
      if (eventAt == null) {
        throw Exception('Для уведомления о прибытии укажите время прибытия');
      }
      if (!reminder.isSent &&
          !eventAt
              .subtract(Duration(minutes: reminder.offsetMinutes))
              .isAfter(DateTime.now())) {
        throw Exception('Время одного из уведомлений уже прошло');
      }
    }

    final newAttachmentCount =
        ticketUploads.length + (ticketBytes == null ? 0 : 1);
    if (newAttachmentCount > maxTicketsPerFlight) {
      throw Exception(
        'К одному вылету можно прикрепить не больше $maxTicketsPerFlight билетов',
      );
    }

    var existingTicketCount = 0;
    if (flightId.trim().isNotEmpty && newAttachmentCount > 0) {
      final existingRows = await _client
          .from('recruitment_flight_tickets')
          .select('id')
          .eq('company_id', candidate.companyId)
          .eq('flight_id', flightId.trim())
          .limit(maxTicketsPerFlight + 1);
      existingTicketCount = existingRows.length;
      if (existingTicketCount == 0 && existing?.hasTicket == true) {
        existingTicketCount = 1;
      }
    }
    if (existingTicketCount + newAttachmentCount > maxTicketsPerFlight) {
      throw Exception(
        'К одному вылету можно прикрепить не больше $maxTicketsPerFlight билетов',
      );
    }

    final ticket = <String, dynamic>{
      'ticket_bucket': existing?.ticketBucket ?? '',
      'ticket_path': existing?.ticketPath ?? '',
      'ticket_original_name': existing?.ticketOriginalName ?? '',
      'ticket_mime_type': existing?.ticketMimeType ?? '',
      'ticket_size_bytes': existing?.ticketSizeBytes,
    };
    final uploadedAttachments = <Map<String, dynamic>>[];
    var totalNewBytes = 0;

    if (ticketBytes != null) {
      totalNewBytes += ticketBytes.length;
      if (totalNewBytes > maxTotalTicketBytes) {
        throw Exception('Общий размер новых билетов должен быть не больше 100 МБ');
      }
      final uploaded = await _uploadTicket(
        companyId: candidate.companyId,
        applicationId: candidate.applicationId,
        fileName: ticketFileName,
        bytes: ticketBytes,
      );
      ticket.addAll(uploaded);
      uploadedAttachments.add(uploaded);
    }

    for (final upload in ticketUploads) {
      if (upload.bytes.isEmpty) throw Exception('Файл билета пустой');
      if (upload.bytes.length > maxTicketBytes) {
        throw Exception(
          '${upload.fileName}: файл билета должен быть меньше 20 МБ',
        );
      }
      totalNewBytes += upload.bytes.length;
      if (totalNewBytes > maxTotalTicketBytes) {
        throw Exception('Общий размер новых билетов должен быть не больше 100 МБ');
      }
      uploadedAttachments.add(
        await _uploadTicket(
          companyId: candidate.companyId,
          applicationId: candidate.applicationId,
          fileName: upload.fileName,
          bytes: upload.bytes,
        ),
      );
    }

    if ((ticket['ticket_path']?.toString() ?? '').isEmpty &&
        uploadedAttachments.isNotEmpty) {
      ticket.addAll(uploadedAttachments.first);
    }
    if ((ticket['ticket_path']?.toString() ?? '').isEmpty) {
      throw Exception('Прикрепите хотя бы один купленный билет');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'company_id': candidate.companyId,
      'application_id': candidate.applicationId,
      'employee_id': candidate.employeeId.trim().isEmpty
          ? null
          : candidate.employeeId.trim(),
      'object_id': candidate.objectId.trim().isEmpty
          ? null
          : candidate.objectId.trim(),
      'departure_at': departureAt.toUtc().toIso8601String(),
      'arrival_at': arrivalAt?.toUtc().toIso8601String(),
      'origin': origin.trim(),
      'destination': destination.trim(),
      'flight_number': flightNumber.trim().toUpperCase(),
      'remind_day_before': false,
      'remind_three_hours': false,
      'notes': notes.trim(),
      ...ticket,
      'updated_by': userId,
      'updated_at': now,
    };

    final dynamic row;
    if (flightId.trim().isEmpty) {
      payload['created_by'] = userId;
      row = await _client
          .from('recruitment_flights')
          .insert(payload)
          .select()
          .single();
    } else {
      row = await _client
          .from('recruitment_flights')
          .update(payload)
          .eq('company_id', candidate.companyId)
          .eq('id', flightId.trim())
          .select()
          .single();
    }

    final result = RecruitmentFlight.fromMap(_map(row));

    await _client.rpc(
      'replace_recruitment_flight_reminders',
      params: <String, dynamic>{
        'p_flight_id': result.id,
        'p_reminders': reminders.map((item) => item.toPayload()).toList(),
      },
    );

    if (uploadedAttachments.isNotEmpty) {
      final attachmentRows = uploadedAttachments
          .map(
            (item) => <String, dynamic>{
              'company_id': candidate.companyId,
              'flight_id': result.id,
              'bucket': item['ticket_bucket'],
              'path': item['ticket_path'],
              'original_name': item['ticket_original_name'],
              'mime_type': item['ticket_mime_type'],
              'size_bytes': item['ticket_size_bytes'],
              'created_by': userId,
            },
          )
          .toList(growable: false);
      await _client.from('recruitment_flight_tickets').insert(attachmentRows);
    }

    await _client
        .from('recruitment_applications')
        .update(<String, dynamic>{
          'ready_date': _dateOnly(departureAt),
          'updated_at': now,
        })
        .eq('company_id', candidate.companyId)
        .eq('id', candidate.applicationId);

    if (candidate.employeeId.trim().isNotEmpty &&
        candidate.objectId.trim().isNotEmpty) {
      await _client.from('employee_mobilizations').upsert(
        <String, dynamic>{
          'company_id': candidate.companyId,
          'application_id': candidate.applicationId,
          'employee_id': candidate.employeeId,
          'object_id': candidate.objectId,
          'planned_start_date': _dateOnly(departureAt),
          'ticket_booked': true,
          'created_by': userId,
          'updated_by': userId,
          'updated_at': now,
        },
        onConflict: 'company_id,employee_id',
      );
    }

    _notify(result.id);
    return result;
  }

  static Future<void> setStatus({
    required RecruitmentFlight flight,
    required String status,
  }) async {
    const allowed = <String>{
      'scheduled',
      'checked_in',
      'departed',
      'arrived',
      'cancelled',
    };
    if (!allowed.contains(status)) return;
    await _client
        .from('recruitment_flights')
        .update(<String, dynamic>{
          'status': status,
          'updated_by': _client.auth.currentUser?.id,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('company_id', flight.companyId)
        .eq('id', flight.id);
    _notify(flight.id);
  }

  static Future<String> createTicketUrl(RecruitmentFlight flight) async {
    if (!flight.hasTicket) throw Exception('Билет не прикреплён');
    return _client.storage
        .from(flight.ticketBucket)
        .createSignedUrl(flight.ticketPath, 300);
  }

  static Future<String> createFlightTicketUrl(
    RecruitmentFlightTicket ticket,
  ) async {
    if (ticket.bucket.trim().isEmpty || ticket.path.trim().isEmpty) {
      throw Exception('Билет не прикреплён');
    }
    return _client.storage.from(ticket.bucket).createSignedUrl(ticket.path, 300);
  }

  static String reminderMessage(
    RecruitmentFlightEntry entry, {
    String kind = 'manual',
  }) {
    final local = entry.flight.departureAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final prefix = switch (kind) {
      'day_before' => 'Напоминаем: завтра вылет',
      'three_hours' => 'До вылета осталось около 3 часов',
      _ => 'Напоминаем о предстоящем вылете',
    };
    return '$prefix $day.$month.${local.year} в $hour:$minute. '
        'Маршрут: ${entry.flight.routeTitle}. '
        '${entry.flight.flightNumber.isEmpty ? '' : 'Рейс ${entry.flight.flightNumber}. '}'
        'Проверьте документы и приезжайте в аэропорт заранее.';
  }

  static Future<RecruitmentFlightReminderResult> sendReminder(
    RecruitmentFlightEntry entry, {
    String kind = 'manual',
  }) async {
    final message = reminderMessage(entry, kind: kind);
    final dynamic raw = await _client.rpc(
      'send_recruitment_flight_reminder',
      params: <String, dynamic>{
        'p_flight_id': entry.flight.id,
        'p_kind': kind,
        'p_message': message,
      },
    );
    final result = RecruitmentFlightReminderResult.fromMap(_map(raw));
    if (result.notificationId.isNotEmpty) {
      unawaited(
        PushNotificationService.dispatchNotification(result.notificationId),
      );
    }
    if (entry.candidate.canMessageInBot) {
      await RecruitmentRepository.sendCandidateMessage(
        applicationId: entry.candidate.applicationId,
        message: message,
        source: entry.candidate.source,
      );
    }
    _notify(entry.flight.id);
    return result;
  }

  static Future<void> dispatchDueReminders({
    required List<RecruitmentFlightCandidate> candidates,
  }) async {
    final dynamic raw = await _client.rpc(
      'dispatch_due_recruitment_flight_reminders',
    );
    if (raw is! List || raw.isEmpty) return;
    final byApplication = <String, RecruitmentFlightCandidate>{
      for (final candidate in candidates) candidate.applicationId: candidate,
    };
    for (final value in raw) {
      final result = RecruitmentFlightReminderResult.fromMap(_map(value));
      if (result.notificationId.isNotEmpty) {
        unawaited(
          PushNotificationService.dispatchNotification(result.notificationId),
        );
      }
      final candidate = byApplication[result.applicationId];
      if (candidate != null &&
          candidate.canMessageInBot &&
          result.message.trim().isNotEmpty) {
        try {
          await RecruitmentRepository.sendCandidateMessage(
            applicationId: candidate.applicationId,
            message: result.message,
            source: candidate.source,
          );
        } catch (_) {
          // Внутреннее и push-уведомление уже созданы; ошибка бота не повторяет их.
        }
      }
    }
  }
}
