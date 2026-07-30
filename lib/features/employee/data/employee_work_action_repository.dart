import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/task_photo_models.dart';

class EmployeeWorkSelection {
  final String employeeId;
  final String objectId;
  final String objectName;

  const EmployeeWorkSelection({
    required this.employeeId,
    required this.objectId,
    required this.objectName,
  });
}

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

class EmployeeObjectGeofence {
  final String objectId;
  final double latitude;
  final double longitude;
  final double radiusM;

  const EmployeeObjectGeofence({
    required this.objectId,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
  });

  factory EmployeeObjectGeofence.fromJson(Map<String, dynamic> json) {
    return EmployeeObjectGeofence(
      objectId: _text(json['object_id']),
      latitude: _number(json['latitude']),
      longitude: _number(json['longitude']),
      radiusM: _number(json['radius_m']),
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
  final double startLatitude;
  final double startLongitude;
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
      startLatitude: _number(json['start_latitude']),
      startLongitude: _number(json['start_longitude']),
      endLatitude: _nullableNumber(json['end_latitude']),
      endLongitude: _nullableNumber(json['end_longitude']),
    );
  }
}

class EmployeeShiftState {
  final String employeeId;
  final EmployeeWorkShift? activeShift;
  final EmployeeObjectGeofence? geofence;

  const EmployeeShiftState({
    required this.employeeId,
    required this.activeShift,
    required this.geofence,
  });

  bool get isActive => activeShift?.isActive == true;
  bool get geofenceConfigured => geofence != null;

  factory EmployeeShiftState.fromJson(Map<String, dynamic> json) {
    final shift = _map(json['active_shift']);
    final geofence = _map(json['geofence']);
    return EmployeeShiftState(
      employeeId: _text(json['employee_id']),
      activeShift: shift.isEmpty ? null : EmployeeWorkShift.fromJson(shift),
      geofence: geofence.isEmpty
          ? null
          : EmployeeObjectGeofence.fromJson(geofence),
    );
  }
}

class EmployeeRouteDay {
  final String employeeId;
  final DateTime workDate;
  final List<EmployeeWorkShift> shifts;
  final List<EmployeeLocationPoint> points;
  final List<EmployeeObjectGeofence> geofences;

  const EmployeeRouteDay({
    required this.employeeId,
    required this.workDate,
    required this.shifts,
    required this.points,
    required this.geofences,
  });

  bool get isEmpty => shifts.isEmpty && points.isEmpty;

  factory EmployeeRouteDay.fromJson(Map<String, dynamic> json) {
    return EmployeeRouteDay(
      employeeId: _text(json['employee_id']),
      workDate: DateTime.tryParse(_text(json['work_date'])) ?? DateTime.now(),
      shifts: _list(json['shifts'])
          .whereType<Map>()
          .map((row) => EmployeeWorkShift.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList(growable: false),
      points: _list(json['points'])
          .whereType<Map>()
          .map((row) => EmployeeLocationPoint.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList(growable: false),
      geofences: _list(json['geofences'])
          .whereType<Map>()
          .map((row) => EmployeeObjectGeofence.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList(growable: false),
    );
  }
}

class EmployeeWorkActionRepository {
  EmployeeWorkActionRepository._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<Map<String, dynamic>> _invoke(
    String action, {
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final response = await _client.functions.invoke(
      'employee-work-actions',
      body: <String, dynamic>{'action': action, ...body},
    );
    final raw = response.data;
    if (raw is! Map) {
      throw Exception('Рабочее действие вернуло некорректный ответ');
    }
    final data = Map<String, dynamic>.from(raw);
    final error = data['error']?.toString().trim() ?? '';
    if (error.isNotEmpty) throw Exception(error);
    return data;
  }

  static Future<EmployeeWorkSelection> resolveSelection() async {
    final data = await _invoke('resolve_selection');
    final employeeId = _text(data['employee_id']);
    if (employeeId.isEmpty) {
      throw Exception('Не удалось определить выбранного сотрудника');
    }
    return EmployeeWorkSelection(
      employeeId: employeeId,
      objectId: _text(data['object_id']),
      objectName: _text(data['object_name']),
    );
  }

  static Future<EmployeeShiftState> fetchShiftState({
    String employeeId = '',
  }) async {
    final data = await _invoke(
      'shift_state',
      body: <String, dynamic>{
        if (employeeId.trim().isNotEmpty) 'employee_id': employeeId.trim(),
      },
    );
    return EmployeeShiftState.fromJson(data);
  }

  static Future<EmployeeWorkShift> startShift({
    required EmployeeLocationPoint point,
    required String permissionScope,
    required String trackingMode,
  }) async {
    final data = await _invoke(
      'start_shift',
      body: <String, dynamic>{
        'permission_scope': permissionScope,
        'tracking_mode': trackingMode,
        'work_date': _dateKey(DateTime.now()),
        ...point.toJson(),
      },
    );
    final shift = _map(data['active_shift']);
    if (shift.isEmpty) throw Exception('Смена не была создана');
    return EmployeeWorkShift.fromJson(shift);
  }

  static Future<void> appendRoutePoints(
    List<EmployeeLocationPoint> points,
  ) async {
    if (points.isEmpty) return;
    await _invoke(
      'append_route_points',
      body: <String, dynamic>{
        'points': points.map((point) => point.toJson()).toList(growable: false),
      },
    );
  }

  static Future<EmployeeWorkShift> finishShift(
    EmployeeLocationPoint point,
  ) async {
    final data = await _invoke(
      'finish_shift',
      body: point.toJson(),
    );
    final shift = _map(data['completed_shift']);
    if (shift.isEmpty) throw Exception('Смена не была завершена');
    return EmployeeWorkShift.fromJson(shift);
  }

  static Future<EmployeeRouteDay> fetchEmployeeRoute({
    required String employeeId,
    required DateTime date,
  }) async {
    final data = await _invoke(
      'route_for_employee',
      body: <String, dynamic>{
        'employee_id': employeeId.trim(),
        'work_date': _dateKey(date),
      },
    );
    return EmployeeRouteDay.fromJson(data);
  }

  static Future<EmployeeObjectGeofence> setObjectGeofence({
    required String objectId,
    required EmployeeLocationPoint point,
    required double radiusM,
  }) async {
    final data = await _invoke(
      'set_object_geofence',
      body: <String, dynamic>{
        'object_id': objectId.trim(),
        'radius_m': radiusM.round(),
        ...point.toJson(),
      },
    );
    final geofence = _map(data['geofence']);
    if (geofence.isEmpty) throw Exception('Геозона не была сохранена');
    return EmployeeObjectGeofence.fromJson(geofence);
  }

  static Future<void> startTask(String taskId) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) throw Exception('Задача не определена');
    await _invoke('start_task', body: <String, dynamic>{'task_id': cleanTaskId});
  }

  static Future<void> uploadTaskPhotos({
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
        body: <String, dynamic>{
          'task_id': cleanTaskId,
          'photo_stage': stage,
          'original_name': photo.originalName,
          'content_type': photo.contentType,
          'extension': photo.extension,
          'base64': base64Encode(photo.bytes),
        },
      );
    }
  }
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
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _dateKey(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
}
