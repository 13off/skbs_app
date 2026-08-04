import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeRouteGeofence {
  final String objectId;
  final String objectName;
  final double latitude;
  final double longitude;
  final double radiusM;

  const EmployeeRouteGeofence({
    required this.objectId,
    required this.objectName,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
  });

  factory EmployeeRouteGeofence.fromMap(Map<String, dynamic> map) {
    return EmployeeRouteGeofence(
      objectId: map['object_id']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      latitude: _number(map['latitude']),
      longitude: _number(map['longitude']),
      radiusM: _number(map['radius_m']),
    );
  }
}

abstract final class EmployeeRouteAnalysisRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<EmployeeRouteGeofence>> fetchGeofences({
    required String employeeId,
    required DateTime date,
  }) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) return const <EmployeeRouteGeofence>[];
    try {
      final raw = await _client.rpc(
        'get_employee_route_geofences',
        params: <String, dynamic>{
          'p_employee_id': cleanEmployeeId,
          'p_work_date': _dateKey(date),
        },
      );
      if (raw is! List) return const <EmployeeRouteGeofence>[];
      return raw
          .whereType<Map>()
          .map(
            (row) =>
                EmployeeRouteGeofence.fromMap(Map<String, dynamic>.from(row)),
          )
          .where(
            (item) =>
                item.objectId.isNotEmpty &&
                item.latitude >= -90 &&
                item.latitude <= 90 &&
                item.longitude >= -180 &&
                item.longitude <= 180 &&
                item.radiusM > 0,
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  static Future<void> cancelRecentShift({required String employeeId}) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) throw Exception('Сотрудник не определён');
    try {
      await _client.rpc(
        'cancel_recent_employee_shift',
        params: <String, dynamic>{'p_employee_id': cleanEmployeeId},
      );
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }
}

String _dateKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
