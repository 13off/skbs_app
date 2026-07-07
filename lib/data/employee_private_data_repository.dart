import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_private_data.dart';

class EmployeePrivateDataRepository {
  static final _client = Supabase.instance.client;

  static Future<EmployeePrivateData?> fetchByEmployeeId(
    String employeeId,
  ) async {
    final row = await _client
        .from('employee_private_data')
        .select()
        .eq('employee_id', employeeId)
        .maybeSingle();

    if (row == null) return null;

    return EmployeePrivateData.fromMap(row);
  }

  static Future<Map<String, EmployeePrivateData>> fetchAllMap() async {
    final rows = await _client.from('employee_private_data').select();

    final result = <String, EmployeePrivateData>{};

    for (final row in rows) {
      final data = EmployeePrivateData.fromMap(row);

      if (data.employeeId.isEmpty) continue;

      result[data.employeeId] = data;
    }

    return result;
  }

  static Future<Map<String, EmployeePrivateData>> fetchMapByEmployeeIds(
    List<String> employeeIds,
  ) async {
    final ids = employeeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) return <String, EmployeePrivateData>{};

    final result = <String, EmployeePrivateData>{};
    const chunkSize = 80;

    for (var start = 0; start < ids.length; start += chunkSize) {
      final end = math.min(start + chunkSize, ids.length);
      final chunk = ids.sublist(start, end);

      final rows = await _client
          .from('employee_private_data')
          .select()
          .inFilter('employee_id', chunk);

      for (final row in rows) {
        final data = EmployeePrivateData.fromMap(row);

        if (data.employeeId.isEmpty) continue;

        result[data.employeeId] = data;
      }
    }

    return result;
  }

  static Future<void> upsert(EmployeePrivateData data) async {
    await _client
        .from('employee_private_data')
        .upsert(data.toSupabaseMap(), onConflict: 'employee_id');
  }
}
