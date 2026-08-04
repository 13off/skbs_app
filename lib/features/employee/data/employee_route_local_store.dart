import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'employee_shift_action_repository.dart';

class EmployeeTrackingGapDraft {
  final String shiftId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String reason;
  final String details;

  const EmployeeTrackingGapDraft({
    required this.shiftId,
    required this.startedAt,
    required this.reason,
    this.endedAt,
    this.details = '',
  });

  bool get isCompleted => endedAt != null;

  EmployeeTrackingGapDraft complete(DateTime value) {
    return EmployeeTrackingGapDraft(
      shiftId: shiftId,
      startedAt: startedAt,
      endedAt: value,
      reason: reason,
      details: details,
    );
  }

  factory EmployeeTrackingGapDraft.fromJson(Map<String, dynamic> json) {
    final startedAt = DateTime.tryParse(
      json['started_at']?.toString() ?? '',
    )?.toLocal();
    if (startedAt == null) {
      throw const FormatException('Некорректное начало разрыва');
    }
    return EmployeeTrackingGapDraft(
      shiftId: json['shift_id']?.toString().trim() ?? '',
      startedAt: startedAt,
      endedAt: DateTime.tryParse(json['ended_at']?.toString() ?? '')?.toLocal(),
      reason: json['reason']?.toString().trim() ?? 'tracking_interruption',
      details: json['details']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'shift_id': shiftId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt?.toUtc().toIso8601String(),
    'reason': reason,
    'details': details,
  };
}

class EmployeeRouteLocalState {
  final String employeeId;
  final String shiftId;
  final List<EmployeeLocationPoint> pendingPoints;
  final List<EmployeeTrackingGapDraft> pendingGaps;
  final EmployeeTrackingGapDraft? openGap;
  final DateTime? lastCapturedAt;

  const EmployeeRouteLocalState({
    required this.employeeId,
    required this.shiftId,
    required this.pendingPoints,
    required this.pendingGaps,
    required this.openGap,
    required this.lastCapturedAt,
  });

  const EmployeeRouteLocalState.empty({
    required this.employeeId,
    required this.shiftId,
  }) : pendingPoints = const <EmployeeLocationPoint>[],
       pendingGaps = const <EmployeeTrackingGapDraft>[],
       openGap = null,
       lastCapturedAt = null;
}

class EmployeeRouteLocalStore {
  static const _prefix = 'employee_route_local_state_v2_';

  Future<EmployeeRouteLocalState> load({
    required String employeeId,
    required String shiftId,
  }) async {
    final cleanEmployeeId = employeeId.trim();
    final cleanShiftId = shiftId.trim();
    if (cleanEmployeeId.isEmpty || cleanShiftId.isEmpty) {
      return EmployeeRouteLocalState.empty(
        employeeId: cleanEmployeeId,
        shiftId: cleanShiftId,
      );
    }

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(cleanEmployeeId));
    if (raw == null || raw.trim().isEmpty) {
      return EmployeeRouteLocalState.empty(
        employeeId: cleanEmployeeId,
        shiftId: cleanShiftId,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      final data = Map<String, dynamic>.from(decoded);
      if ((data['shift_id']?.toString().trim() ?? '') != cleanShiftId) {
        await clear(cleanEmployeeId);
        return EmployeeRouteLocalState.empty(
          employeeId: cleanEmployeeId,
          shiftId: cleanShiftId,
        );
      }

      final points = <EmployeeLocationPoint>[];
      final rawPoints = data['pending_points'];
      if (rawPoints is List) {
        for (final value in rawPoints) {
          if (value is Map) {
            points.add(
              EmployeeLocationPoint.fromJson(Map<String, dynamic>.from(value)),
            );
          }
        }
      }

      final gaps = <EmployeeTrackingGapDraft>[];
      final rawGaps = data['pending_gaps'];
      if (rawGaps is List) {
        for (final value in rawGaps) {
          if (value is Map) {
            final gap = EmployeeTrackingGapDraft.fromJson(
              Map<String, dynamic>.from(value),
            );
            if (gap.isCompleted) gaps.add(gap);
          }
        }
      }

      EmployeeTrackingGapDraft? openGap;
      final rawOpenGap = data['open_gap'];
      if (rawOpenGap is Map) {
        final gap = EmployeeTrackingGapDraft.fromJson(
          Map<String, dynamic>.from(rawOpenGap),
        );
        if (!gap.isCompleted) openGap = gap;
      }

      return EmployeeRouteLocalState(
        employeeId: cleanEmployeeId,
        shiftId: cleanShiftId,
        pendingPoints: points,
        pendingGaps: gaps,
        openGap: openGap,
        lastCapturedAt: DateTime.tryParse(
          data['last_captured_at']?.toString() ?? '',
        )?.toLocal(),
      );
    } catch (_) {
      await clear(cleanEmployeeId);
      return EmployeeRouteLocalState.empty(
        employeeId: cleanEmployeeId,
        shiftId: cleanShiftId,
      );
    }
  }

  Future<void> save({
    required String employeeId,
    required String shiftId,
    required List<EmployeeLocationPoint> pendingPoints,
    required List<EmployeeTrackingGapDraft> pendingGaps,
    required EmployeeTrackingGapDraft? openGap,
    required DateTime? lastCapturedAt,
  }) async {
    final cleanEmployeeId = employeeId.trim();
    final cleanShiftId = shiftId.trim();
    if (cleanEmployeeId.isEmpty || cleanShiftId.isEmpty) return;

    final payload = jsonEncode(<String, dynamic>{
      'version': 2,
      'employee_id': cleanEmployeeId,
      'shift_id': cleanShiftId,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'last_captured_at': lastCapturedAt?.toUtc().toIso8601String(),
      'pending_points': pendingPoints
          .map((point) => point.toJson())
          .toList(growable: false),
      'pending_gaps': pendingGaps
          .map((gap) => gap.toJson())
          .toList(growable: false),
      'open_gap': openGap?.toJson(),
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(cleanEmployeeId), payload);
  }

  Future<void> clear(String employeeId) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(cleanEmployeeId));
  }

  String _key(String employeeId) => '$_prefix$employeeId';
}
