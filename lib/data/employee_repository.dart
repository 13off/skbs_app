import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';

class EmployeeRepository {
  static final _client = Supabase.instance.client;

  static const List<String> baseObjects = ['Мурманск', 'Москва'];
  static const Duration _employeesCacheTtl = Duration(seconds: 25);

  static List<String>? _cachedObjectNames;
  static final Map<String, _EmployeesCacheEntry> _employeesCache = {};

  static String? cleanObjectName(String? objectName) {
    final clean = objectName?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  static void clearCache() {
    _cachedObjectNames = null;
    _employeesCache.clear();
  }

  static String _employeesCacheKey({
    required String? objectName,
    required bool includeFired,
  }) {
    final objectPart = cleanObjectName(objectName) ?? '__all__';
    final firedPart = includeFired ? 'with_fired' : 'active_only';

    return '$objectPart::$firedPart';
  }

  static bool _isEmployeesCacheFresh(_EmployeesCacheEntry entry) {
    return DateTime.now().difference(entry.createdAt) < _employeesCacheTtl;
  }

  static List<Employee> _copyEmployees(List<Employee> employees) {
    return List<Employee>.from(employees);
  }

  static List<Employee> _sortEmployees(List<Employee> employees) {
    employees.sort((a, b) => a.name.compareTo(b.name));
    return employees;
  }

  static Stream<List<Employee>> watchEmployees({
    String? objectName,
    bool includeFired = false,
  }) {
    final cleanObject = cleanObjectName(objectName);

    return _client.from('employees').stream(primaryKey: ['id']).map((rows) {
      final filteredRows = rows.where((row) {
        final isActive = row['is_active'] as bool? ?? true;

        if (!includeFired && !isActive) return false;

        if (cleanObject != null) {
          final rowObject = row['object_name']?.toString().trim();

          if (rowObject != cleanObject) return false;
        }

        return true;
      }).toList();

      final employees = filteredRows.map<Employee>((row) {
        return Employee.fromSupabase(row);
      }).toList();

      return _sortEmployees(employees);
    });
  }

  static Future<List<Employee>> fetchEmployees({
    String? objectName,
    bool includeFired = false,
    bool forceRefresh = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);
    final cacheKey = _employeesCacheKey(
      objectName: cleanObject,
      includeFired: includeFired,
    );

    final cached = _employeesCache[cacheKey];

    if (!forceRefresh && cached != null && _isEmployeesCacheFresh(cached)) {
      return _copyEmployees(cached.employees);
    }

    const fields =
        'id, fio, position, phone, object_name, daily_rate, is_active, comment';

    late final List<dynamic> rows;

    if (cleanObject == null && includeFired) {
      rows = await _client
          .from('employees')
          .select(fields)
          .order('fio', ascending: true);
    } else if (cleanObject == null && !includeFired) {
      rows = await _client
          .from('employees')
          .select(fields)
          .eq('is_active', true)
          .order('fio', ascending: true);
    } else if (cleanObject != null && includeFired) {
      rows = await _client
          .from('employees')
          .select(fields)
          .eq('object_name', cleanObject)
          .order('fio', ascending: true);
    } else {
      rows = await _client
          .from('employees')
          .select(fields)
          .eq('object_name', cleanObject!)
          .eq('is_active', true)
          .order('fio', ascending: true);
    }

    final employees = _employeesFromRows(rows);

    _employeesCache[cacheKey] = _EmployeesCacheEntry(
      employees: _copyEmployees(employees),
      createdAt: DateTime.now(),
    );

    return _copyEmployees(employees);
  }

  static List<Employee> _employeesFromRows(List<dynamic> rows) {
    final employees = rows.map<Employee>((row) {
      return Employee.fromSupabase(row as Map<String, dynamic>);
    }).toList();

    return _sortEmployees(employees);
  }

  static Future<List<String>> fetchObjectNames({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedObjectNames != null) {
      return List<String>.from(_cachedObjectNames!);
    }

    final rows = await _client
        .from('employees')
        .select('object_name')
        .eq('is_active', true);

    final objects = <String>{...baseObjects};

    for (final row in rows) {
      final objectName = row['object_name']?.toString().trim();

      if (objectName == null || objectName.isEmpty) continue;

      objects.add(objectName);
    }

    final result = objects.toList();
    result.sort();

    _cachedObjectNames = result;

    return List<String>.from(result);
  }

  static Future<String?> addEmployee({
    required String fio,
    required String position,
    required String phone,
    required String objectName,
    required int dailyRate,
    required String comment,
  }) async {
    final row = await _client
        .from('employees')
        .insert({
          'fio': fio.trim(),
          'position': position.trim(),
          'phone': phone.trim(),
          'object_name': objectName.trim().isEmpty
              ? 'Мурманск'
              : objectName.trim(),
          'daily_rate': dailyRate,
          'is_active': true,
          'comment': comment.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    clearCache();

    final employeeId = row['id']?.toString();

    if (employeeId != null && employeeId.isNotEmpty) {
      await syncEmployeePhoneToPrivateData(
        employeeId: employeeId,
        phone: phone,
      );
    }

    return employeeId;
  }

  static Future<void> updateEmployee({
    required String employeeId,
    required String fio,
    required String position,
    required String phone,
    required String objectName,
    required int dailyRate,
    required String comment,
  }) async {
    await _client
        .from('employees')
        .update({
          'fio': fio.trim(),
          'position': position.trim(),
          'phone': phone.trim(),
          'object_name': objectName.trim().isEmpty
              ? 'Мурманск'
              : objectName.trim(),
          'daily_rate': dailyRate,
          'comment': comment.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', employeeId);

    clearCache();

    await syncEmployeePhoneToPrivateData(employeeId: employeeId, phone: phone);
  }

  static Future<void> syncEmployeePhoneToPrivateData({
    required String employeeId,
    required String phone,
  }) async {
    final cleanPhone = phone.trim();

    if (employeeId.trim().isEmpty || cleanPhone.isEmpty) return;

    final existing = await _client
        .from('employee_private_data')
        .select('employee_id, phone')
        .eq('employee_id', employeeId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('employee_private_data').insert({
        'employee_id': employeeId,
        'phone': cleanPhone,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return;
    }

    final existingPhone = existing['phone']?.toString().trim() ?? '';

    // Если в личных данных телефон уже вручную изменили,
    // не перетираем его телефоном из карточки сотрудника.
    if (existingPhone.isNotEmpty) return;

    await _client
        .from('employee_private_data')
        .update({
          'phone': cleanPhone,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('employee_id', employeeId);
  }

  static Future<void> setEmployeeActive({
    required String employeeId,
    required bool isActive,
  }) async {
    await _client
        .from('employees')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', employeeId);

    clearCache();
  }
}

class _EmployeesCacheEntry {
  final List<Employee> employees;
  final DateTime createdAt;

  const _EmployeesCacheEntry({
    required this.employees,
    required this.createdAt,
  });
}
