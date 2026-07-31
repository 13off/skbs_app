import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/task_photo_models.dart';

class EmployeeLocationPoint {
  final double latitude;
  final double longitude;
  final double accuracyM;
  final double? altitudeM;
  final double? speedMps;
  final double? headingDeg;
  final bool isMock;
  final DateTime recordedAt;
  final String source;
  final String shiftId;

  const EmployeeLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.recordedAt,
    this.altitudeM,
    this.speedMps,
    this.headingDeg,
    this.isMock = false,
    this.source = 'device',
    this.shiftId = '',
  });

  factory EmployeeLocationPoint.fromJson(Map<String, dynamic> json) {
    return EmployeeLocationPoint(
      latitude: _number(json['latitude']),
      longitude: _number(json['longitude']),
      accuracyM: _number(json['accuracy_m']),
      altitudeM: _nullableNumber(json['altitude_m']),
      speedMps: _nullableNumber(json['speed_mps']),
      headingDeg: _nullableNumber(json['heading_deg']),
      isMock: json['is_mock'] as bool? ?? false,
      recordedAt: DateTime.tryParse(_text(json['recorded_at']))?.toLocal() ??
          DateTime.now(),
      source: _text(json['source']),
      shiftId: _text(json['shift_id']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyM,
        'altitude_m': altitudeM,
        'speed_mps': speedMps,
        'heading_deg': headingDeg,
        'is_mock': isMock,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };
}

class EmployeeTrackingGap {
  final String id;
  final String shiftId;
  final String employeeId;
  final DateTime startedAt;
  final DateTime endedAt;
  final String reason;
  final String details;
  final bool inferred;

  const EmployeeTrackingGap({
    required this.id,
    required this.shiftId,
    required this.employeeId,
    required this.startedAt,
    required this.endedAt,
    required this.reason,
    required this.details,
    this.inferred = false,
  });

  Duration get duration => endedAt.difference(startedAt);

  factory EmployeeTrackingGap.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(_text(json['started_at']))?.toLocal() ??
        DateTime.now();
    final end =
        DateTime.tryParse(_text(json['ended_at']))?.toLocal() ?? start;
    return EmployeeTrackingGap(
      id: _text(json['id']),
      shiftId: _text(json['shift_id']),
      employeeId: _text(json['employee_id']),
      startedAt: start,
      endedAt: end.isBefore(start) ? start : end,
      reason: _text(json['reason']),
      details: _text(json['details']),
    );
  }
}

class EmployeeWorkShift {
  final String id;
  final String employeeId;
  final String taskId;
  final String objectId;
  final DateTime? workDate;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String permissionScope;
  final String trackingMode;
  final int routePointCount;
  final DateTime? lastPointAt;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;

  const EmployeeWorkShift({
    required this.id,
    required this.employeeId,
    required this.taskId,
    required this.objectId,
    required this.workDate,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.permissionScope,
    required this.trackingMode,
    required this.routePointCount,
    required this.lastPointAt,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
  });

  bool get isActive => status == 'active';

  factory EmployeeWorkShift.fromJson(Map<String, dynamic> json) {
    return EmployeeWorkShift(
      id: _text(json['id']),
      employeeId: _text(json['employee_id']),
      taskId: _text(json['task_id']),
      objectId: _text(json['object_id']),
      workDate: DateTime.tryParse(_text(json['work_date'])),
      status: _text(json['status']),
      startedAt: DateTime.tryParse(_text(json['started_at']))?.toLocal(),
      endedAt: DateTime.tryParse(_text(json['ended_at']))?.toLocal(),
      permissionScope: _text(json['permission_scope']),
      trackingMode: _text(json['tracking_mode']),
      routePointCount: _integer(json['route_point_count']),
      lastPointAt: DateTime.tryParse(_text(json['last_point_at']))?.toLocal(),
      startLatitude: _nullableNumber(json['start_latitude']),
      startLongitude: _nullableNumber(json['start_longitude']),
      endLatitude: _nullableNumber(json['end_latitude']),
      endLongitude: _nullableNumber(json['end_longitude']),
    );
  }
}

class EmployeeShiftState {
  final String employeeId;
  final EmployeeWorkShift? activeShift;

  const EmployeeShiftState({
    required this.employeeId,
    required this.activeShift,
  });

  bool get isActive => activeShift?.isActive == true;

  factory EmployeeShiftState.fromJson(Map<String, dynamic> json) {
    final shift = _map(json['active_shift']);
    return EmployeeShiftState(
      employeeId: _text(json['employee_id']),
      activeShift: shift.isEmpty ? null : EmployeeWorkShift.fromJson(shift),
    );
  }
}

class EmployeeRouteDay {
  static const Duration inferredGapThreshold = Duration(minutes: 4);

  final String employeeId;
  final DateTime workDate;
  final List<EmployeeWorkShift> shifts;
  final List<EmployeeLocationPoint> points;
  final List<EmployeeTrackingGap> gaps;

  const EmployeeRouteDay({
    required this.employeeId,
    required this.workDate,
    required this.shifts,
    required this.points,
    this.gaps = const <EmployeeTrackingGap>[],
  });

  bool get isEmpty => shifts.isEmpty && points.isEmpty;

  List<EmployeeTrackingGap> get allGaps {
    final result = List<EmployeeTrackingGap>.from(gaps);
    for (final inferredGap in _inferGaps()) {
      final overlapsRecorded = result.any(
        (recorded) =>
            recorded.startedAt.isBefore(inferredGap.endedAt) &&
            inferredGap.startedAt.isBefore(recorded.endedAt),
      );
      if (!overlapsRecorded) result.add(inferredGap);
    }
    result.sort((left, right) => left.startedAt.compareTo(right.startedAt));
    return result;
  }

  EmployeeRouteDay copyWith({
    List<EmployeeTrackingGap>? gaps,
  }) {
    return EmployeeRouteDay(
      employeeId: employeeId,
      workDate: workDate,
      shifts: shifts,
      points: points,
      gaps: gaps ?? this.gaps,
    );
  }

  factory EmployeeRouteDay.fromJson(Map<String, dynamic> json) {
    return EmployeeRouteDay(
      employeeId: _text(json['employee_id']),
      workDate: DateTime.tryParse(_text(json['work_date'])) ?? DateTime.now(),
      shifts: _list(json['shifts'])
          .whereType<Map>()
          .map(
            (row) => EmployeeWorkShift.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false),
      points: _list(json['points'])
          .whereType<Map>()
          .map(
            (row) => EmployeeLocationPoint.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false),
    );
  }

  List<EmployeeTrackingGap> _inferGaps() {
    final result = <EmployeeTrackingGap>[];
    final now = DateTime.now();
    final isToday = workDate.year == now.year &&
        workDate.month == now.month &&
        workDate.day == now.day;

    for (final shift in shifts) {
      final startedAt = shift.startedAt;
      if (startedAt == null) continue;
      final finishedAt = shift.endedAt ?? (shift.isActive && isToday ? now : null);
      if (finishedAt == null || !finishedAt.isAfter(startedAt)) continue;

      final shiftPoints = points.where((point) {
        if (point.shiftId.isNotEmpty) return point.shiftId == shift.id;
        return !point.recordedAt.isBefore(startedAt) &&
            !point.recordedAt.isAfter(finishedAt);
      }).toList()
        ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));

      var previous = startedAt;
      for (final point in shiftPoints) {
        _appendInferredGap(
          result,
          shift: shift,
          start: previous,
          end: point.recordedAt,
        );
        if (point.recordedAt.isAfter(previous)) previous = point.recordedAt;
      }
      _appendInferredGap(
        result,
        shift: shift,
        start: previous,
        end: finishedAt,
      );
    }
    return result;
  }

  void _appendInferredGap(
    List<EmployeeTrackingGap> target, {
    required EmployeeWorkShift shift,
    required DateTime start,
    required DateTime end,
  }) {
    if (end.difference(start) < inferredGapThreshold) return;
    target.add(
      EmployeeTrackingGap(
        id: 'inferred-${shift.id}-${start.millisecondsSinceEpoch}',
        shiftId: shift.id,
        employeeId: employeeId,
        startedAt: start,
        endedAt: end,
        reason: 'no_coordinates',
        details:
            'Координаты не поступали. Возможные причины: приложение было закрыто, '
            'геолокация отключена или Android ограничил фоновую работу.',
        inferred: true,
      ),
    );
  }
}

class EmployeeShiftActionRepository {
  EmployeeShiftActionRepository._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<Map<String, dynamic>> _invoke(
    String action, {
    required String employeeId,
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) throw Exception('Сотрудник не определён');
    try {
      final response = await _client.functions.invoke(
        'employee-shift-actions',
        body: <String, dynamic>{
          'action': action,
          'employee_id': cleanEmployeeId,
          ...body,
        },
      );
      final raw = response.data;
      if (raw is! Map) throw Exception('Сервер вернул некорректный ответ');
      final data = Map<String, dynamic>.from(raw);
      final error = _text(data['error']);
      if (error.isNotEmpty) throw Exception(error);
      return data;
    } on FunctionException catch (error) {
      throw Exception(_functionError(error));
    }
  }

  static Future<EmployeeShiftState> fetchShiftState({
    required String employeeId,
  }) async {
    final data = await _invoke('shift_state', employeeId: employeeId);
    return EmployeeShiftState.fromJson(data);
  }

  static Future<EmployeeWorkShift> startShift({
    required String employeeId,
    required EmployeeLocationPoint point,
    required String permissionScope,
    required String trackingMode,
  }) async {
    final data = await _invoke(
      'start_shift',
      employeeId: employeeId,
      body: <String, dynamic>{
        'permission_scope': permissionScope,
        'tracking_mode': trackingMode,
        'work_date': _dateKey(DateTime.now()),
        ...point.toJson(),
      },
    );
    final shift = _map(data['active_shift']);
    if (shift.isEmpty) throw Exception('Рабочий день не был начат');
    return EmployeeWorkShift.fromJson(shift);
  }

  static Future<void> appendRoutePoints({
    required String employeeId,
    required List<EmployeeLocationPoint> points,
  }) async {
    if (points.isEmpty) return;
    await _invoke(
      'append_route_points',
      employeeId: employeeId,
      body: <String, dynamic>{
        'points': points.map((point) => point.toJson()).toList(growable: false),
      },
    );
  }

  static Future<void> recordTrackingGap({
    required String employeeId,
    required String shiftId,
    required DateTime startedAt,
    required DateTime endedAt,
    required String reason,
    String details = '',
  }) async {
    if (!endedAt.isAfter(startedAt)) return;
    await _client.rpc(
      'record_employee_tracking_gap',
      params: <String, dynamic>{
        'p_employee_id': employeeId,
        'p_shift_id': shiftId,
        'p_started_at': startedAt.toUtc().toIso8601String(),
        'p_ended_at': endedAt.toUtc().toIso8601String(),
        'p_reason': reason,
        'p_details': details,
      },
    );
  }

  static Future<EmployeeWorkShift> finishShift({
    required String employeeId,
    required EmployeeLocationPoint point,
  }) async {
    final data = await _invoke(
      'finish_shift',
      employeeId: employeeId,
      body: point.toJson(),
    );
    final shift = _map(data['completed_shift']);
    if (shift.isEmpty) throw Exception('Рабочий день не был завершён');
    return EmployeeWorkShift.fromJson(shift);
  }

  static Future<EmployeeRouteDay> fetchEmployeeRoute({
    required String employeeId,
    required DateTime date,
  }) async {
    final data = await _invoke(
      'route_for_employee',
      employeeId: employeeId,
      body: <String, dynamic>{'work_date': _dateKey(date)},
    );
    final route = EmployeeRouteDay.fromJson(data);
    try {
      final gaps = await fetchTrackingGaps(
        employeeId: employeeId,
        date: date,
      );
      return route.copyWith(gaps: gaps);
    } catch (_) {
      // Старая база без миграции продолжит показывать вычисленные разрывы.
      return route;
    }
  }

  static Future<List<EmployeeTrackingGap>> fetchTrackingGaps({
    required String employeeId,
    required DateTime date,
  }) async {
    final raw = await _client.rpc(
      'fetch_employee_tracking_gaps',
      params: <String, dynamic>{
        'p_employee_id': employeeId,
        'p_work_date': _dateKey(date),
      },
    );
    if (raw is! List) return const <EmployeeTrackingGap>[];
    return raw
        .whereType<Map>()
        .map(
          (row) => EmployeeTrackingGap.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  static Future<void> startTask({
    required String employeeId,
    required String taskId,
  }) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) throw Exception('Задача не определена');
    await _invoke(
      'start_task',
      employeeId: employeeId,
      body: <String, dynamic>{'task_id': cleanTaskId},
    );
  }

  static Future<void> uploadTaskPhotos({
    required String employeeId,
    required String taskId,
    required String stage,
    required List<TaskPhotoFile> photos,
  }) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) throw Exception('Задача не определена');
    if (stage != 'before' && stage != 'after') {
      throw Exception('Неизвестный тип фотографии');
    }
    for (final photo in photos) {
      await _invoke(
        'upload_task_photo',
        employeeId: employeeId,
        body: <String, dynamic>{
          'task_id': cleanTaskId,
          'photo_stage': stage,
          'original_name': photo.originalName,
          'content_type': photo.contentType,
          'base64': base64Encode(photo.bytes),
        },
      );
    }
  }
}

String _functionError(FunctionException error) {
  final details = error.details;
  if (details is Map) {
    final message = _text(details['error']);
    if (message.isNotEmpty) return message;
  }
  if (details is String && details.trim().isNotEmpty) return details.trim();
  final reason = error.reasonPhrase?.trim() ?? '';
  if (reason.isNotEmpty) return reason;
  return 'Не удалось выполнить действие';
}

String _dateKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

String _text(dynamic value) => value?.toString().trim() ?? '';

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableNumber(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
