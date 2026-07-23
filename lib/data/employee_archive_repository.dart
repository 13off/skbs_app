import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';
import 'app_data_sync.dart';
import 'employee_repository.dart';

class EmployeeArchiveRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const String _fields =
      'id, fio, position, phone, object_name, daily_rate, is_active, comment, archived_at';
  static const Duration _cacheTtl = Duration(seconds: 30);

  static List<Employee>? _cachedEmployees;
  static DateTime? _cachedAt;
  static Future<List<Employee>>? _inFlight;
  static int _cacheGeneration = 0;

  static bool get _isCacheFresh {
    final cachedAt = _cachedAt;
    return _cachedEmployees != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl;
  }

  static List<Employee> _copyEmployees(List<Employee> employees) {
    return List<Employee>.from(employees);
  }

  static void clearCache() {
    _cachedEmployees = null;
    _cachedAt = null;
    _inFlight = null;
    _cacheGeneration++;
  }

  static Future<List<Employee>> fetchArchivedEmployees({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheFresh) {
      return _copyEmployees(_cachedEmployees!);
    }

    final running = _inFlight;
    if (running != null) return _copyEmployees(await running);

    final generation = _cacheGeneration;
    final request = _loadArchivedEmployees();
    _inFlight = request;
    try {
      final result = await request;
      if (generation == _cacheGeneration) {
        _cachedEmployees = _copyEmployees(result);
        _cachedAt = DateTime.now();
      }
      return _copyEmployees(result);
    } finally {
      if (identical(_inFlight, request)) {
        _inFlight = null;
      }
    }
  }

  static Future<List<Employee>> _loadArchivedEmployees() async {
    final rows = await _client
        .from('employees')
        .select(_fields)
        .not('archived_at', 'is', null)
        .order('fio', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => Employee.fromSupabase(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<Set<String>> fetchArchivedEmployeeIds({
    bool forceRefresh = false,
  }) async {
    final employees = await fetchArchivedEmployees(forceRefresh: forceRefresh);
    return employees
        .map((employee) => employee.id?.trim() ?? '')
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

    clearCache();
    EmployeeRepository.clearCache();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.employees},
      context: <String, dynamic>{
        'table': 'employees',
        'employee_id': id,
      },
    );
  }

  static Future<void> restoreEmployee(String employeeId) async {
    final id = employeeId.trim();
    if (id.isEmpty) throw Exception('Не найден ID сотрудника');

    await _client
        .from('employees')
        .update({
          'is_active': false,
          'archived_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);

    clearCache();
    EmployeeRepository.clearCache();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.employees},
      context: <String, dynamic>{
        'table': 'employees',
        'employee_id': id,
      },
    );
  }
}
