import 'package:supabase_flutter/supabase_flutter.dart';

import 'employee_shift_action_repository.dart';

class EmployeeShiftWebFallbackRepository {
  EmployeeShiftWebFallbackRepository._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<EmployeeWorkShift> startWithoutLocation({
    required String employeeId,
  }) async {
    final raw = await _client.rpc(
      'start_employee_shift_without_location',
      params: <String, dynamic>{
        'p_employee_id': employeeId.trim(),
        'p_work_date': _dateKey(DateTime.now()),
      },
    );
    final data = _map(raw);
    final shift = _map(data['active_shift']);
    if (shift.isEmpty) throw Exception('Рабочий день не был начат');
    return EmployeeWorkShift.fromJson(shift);
  }

  static Future<EmployeeWorkShift> finishWithoutLocation({
    required String employeeId,
  }) async {
    final raw = await _client.rpc(
      'finish_employee_shift_without_location',
      params: <String, dynamic>{'p_employee_id': employeeId.trim()},
    );
    final data = _map(raw);
    final shift = _map(data['completed_shift']);
    if (shift.isEmpty) throw Exception('Рабочий день не был завершён');
    return EmployeeWorkShift.fromJson(shift);
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _dateKey(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
