import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';
import 'employee_repository.dart';

class EmployeeArchiveRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const String _fields =
      'id, fio, position, phone, object_name, daily_rate, is_active, comment, archived_at';

  static Future<List<Employee>> fetchArchivedEmployees() async {
    final rows = await _client
        .from('employees')
        .select(_fields)
        .not('archived_at', 'is', null)
        .order('fio', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => Employee.fromSupabase(row as Map<String, dynamic>))
        .toList();
  }

  static Future<Set<String>> fetchArchivedEmployeeIds() async {
    final rows = await _client
        .from('employees')
        .select('id')
        .not('archived_at', 'is', null);

    return (rows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static Future<void> archiveEmployee(String employeeId) async {
    final id = employeeId.trim();
    if (id.isEmpty) throw Exception('Не найден ID сотрудника');

    await _client
        .from('employees')
        .update({
          'is_active': false,
          'archived_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);

    EmployeeRepository.clearCache();
  }

  static Future<void> restoreEmployee(String employeeId) async {
    final id = employeeId.trim();
    if (id.isEmpty) throw Exception('Не найден ID сотрудника');

    await _client
        .from('employees')
        .update({
          'is_active': true,
          'archived_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);

    EmployeeRepository.clearCache();
  }
}
