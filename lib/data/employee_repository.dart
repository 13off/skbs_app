import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';
import 'object_repository.dart';

class EmployeeRepository {
  static final _client = Supabase.instance.client;

  static const List<String> baseObjects = <String>[];
  static const Duration _employeesCacheTtl = Duration(seconds: 25);

  static List<String>? _cachedObjectNames;
  static final Map<String, _EmployeesCacheEntry> _employeesCache = {};
  static final Map<String, Future<List<Employee>>> _employeeRequests = {};
  static Future<List<String>>? _objectNamesRequest;
  static int _cacheGeneration = 0;

  static String? cleanObjectName(String? objectName) {
    final clean = objectName?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  static void clearCache() {
    _cachedObjectNames = null;
    _employeesCache.clear();
    _employeeRequests.clear();
    _objectNamesRequest = null;
    _cacheGeneration++;
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

    final runningRequest = _employeeRequests[cacheKey];

    if (!forceRefresh && runningRequest != null) {
      final employees = await runningRequest;
      return _copyEmployees(employees);
    }

    final generation = _cacheGeneration;
    final request = _loadEmployees(
      objectName: cleanObject,
      includeFired: includeFired,
    );
    _employeeRequests[cacheKey] = request;

    try {
      final employees = await request;

      if (generation == _cacheGeneration) {
        _employeesCache[cacheKey] = _EmployeesCacheEntry(
          employees: _copyEmployees(employees),
          createdAt: DateTime.now(),
        );
      }

      return _copyEmployees(employees);
    } finally {
      if (identical(_employeeRequests[cacheKey], request)) {
        _employeeRequests.remove(cacheKey);
      }
    }
  }

  static Future<List<Employee>> _loadEmployees({
    required String? objectName,
    required bool includeFired,
  }) async {
    const fields =
        'id, fio, position, phone, object_name, daily_rate, is_active, comment';

    late final List<dynamic> rows;

    if (objectName == null && includeFired) {
      rows = await _client
          .from('employees')
          .select(fields)
          .order('fio', ascending: true);
    } else if (objectName == null && !includeFired) {
      rows = await _client
          .from('employees')
          .select(fields)
          .eq('is_active', true)
          .order('fio', ascending: true);
    } else if (objectName != null && includeFired) {
      rows = await _client
          .from('employees')
          .select(fields)
          .eq('object_name', objectName)
          .order('fio', ascending: true);
    } else {
      rows = await _client
          .from('employees')
          .select(fields)
          .eq('object_name', objectName!)
          .eq('is_active', true)
          .order('fio', ascending: true);
    }

    return _employeesFromRows(rows);
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

    final runningRequest = _objectNamesRequest;

    if (!forceRefresh && runningRequest != null) {
      return List<String>.from(await runningRequest);
    }

    final generation = _cacheGeneration;
    final request = ObjectRepository.fetchObjectNames(
      forceRefresh: forceRefresh,
    );
    _objectNamesRequest = request;

    try {
      final result = await request;

      if (generation == _cacheGeneration) {
        _cachedObjectNames = List<String>.from(result);
      }

      return List<String>.from(result);
    } finally {
      if (identical(_objectNamesRequest, request)) {
        _objectNamesRequest = null;
      }
    }
  }

  static Future<String?> addEmployee({
    required String fio,
    required String position,
    required String phone,
    required String objectName,
    required int dailyRate,
    required String comment,
  }) async {
    final cleanObjectName = objectName.trim();

    if (cleanObjectName.isEmpty) {
      throw Exception('Выберите объект');
    }

    await ObjectRepository.ensureObjectNameExists(cleanObjectName);

    final row = await _client
        .from('employees')
        .insert({
          'fio': fio.trim(),
          'position': position.trim(),
          'phone': phone.trim(),
          'object_name': cleanObjectName,
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
    final cleanObjectName = objectName.trim();

    if (cleanObjectName.isEmpty) {
      throw Exception('Выберите объект');
    }

    await ObjectRepository.ensureObjectNameExists(cleanObjectName);

    await _client
        .from('employees')
        .update({
          'fio': fio.trim(),
          'position': position.trim(),
          'phone': phone.trim(),
          'object_name': cleanObjectName,
          'daily_rate': dailyRate,
          'comment': comment.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', employeeId);

    clearCache();

    await syncEmployeePhoneToPrivateData(employeeId: employeeId, phone: phone);
  }

  static Future<Employee> copyEmployeeToObject({
    required Employee employee,
    required String targetObjectName,
  }) async {
    final sourceEmployeeId = employee.id?.trim() ?? '';
    final cleanTargetObjectName = cleanObjectName(targetObjectName);

    if (sourceEmployeeId.isEmpty) {
      throw Exception('Не найден ID сотрудника');
    }

    if (cleanTargetObjectName == null) {
      throw Exception('Выберите объект');
    }

    final sourceObjectName = employee.objectName.trim();

    if (sourceObjectName == cleanTargetObjectName) {
      throw Exception('Сотрудник уже находится на этом объекте');
    }

    const fields =
        'id, fio, position, phone, object_name, daily_rate, is_active, comment';

    final sourceRow = await _client
        .from('employees')
        .select(fields)
        .eq('id', sourceEmployeeId)
        .single();

    final fio = sourceRow['fio']?.toString().trim() ?? employee.name.trim();

    final existingDuplicate = await _client
        .from('employees')
        .select('id')
        .eq('fio', fio)
        .eq('object_name', cleanTargetObjectName)
        .maybeSingle();

    if (existingDuplicate != null) {
      throw Exception('На объекте "$cleanTargetObjectName" уже есть "$fio"');
    }

    await ObjectRepository.ensureObjectNameExists(cleanTargetObjectName);

    final now = DateTime.now().toUtc().toIso8601String();

    final createdRow = await _client
        .from('employees')
        .insert({
          'fio': fio,
          'position':
              sourceRow['position']?.toString().trim() ??
              employee.position.trim(),
          'phone':
              sourceRow['phone']?.toString().trim() ?? employee.phone.trim(),
          'object_name': cleanTargetObjectName,
          'daily_rate': sourceRow['daily_rate'] as int? ?? employee.dailyRate,
          'is_active': true,
          'comment':
              sourceRow['comment']?.toString().trim() ??
              employee.comment.trim(),
          'updated_at': now,
        })
        .select(fields)
        .single();

    final newEmployee = Employee.fromSupabase(createdRow);
    final newEmployeeId = newEmployee.id?.trim() ?? '';

    if (newEmployeeId.isEmpty) {
      clearCache();
      return newEmployee;
    }

    await copyPrivateDataToEmployee(
      sourceEmployeeId: sourceEmployeeId,
      targetEmployeeId: newEmployeeId,
      fallbackPhone: newEmployee.phone,
    );

    clearCache();

    return newEmployee;
  }

  static Future<void> copyPrivateDataToEmployee({
    required String sourceEmployeeId,
    required String targetEmployeeId,
    required String fallbackPhone,
  }) async {
    final sourcePrivateData = await _client
        .from('employee_private_data')
        .select()
        .eq('employee_id', sourceEmployeeId)
        .maybeSingle();

    if (sourcePrivateData == null) {
      await syncEmployeePhoneToPrivateData(
        employeeId: targetEmployeeId,
        phone: fallbackPhone,
      );
      return;
    }

    final privateDataForInsert = Map<String, dynamic>.from(sourcePrivateData);

    privateDataForInsert.remove('id');
    privateDataForInsert.remove('created_at');
    privateDataForInsert.remove('updated_at');

    privateDataForInsert['employee_id'] = targetEmployeeId;
    privateDataForInsert['updated_at'] = DateTime.now()
        .toUtc()
        .toIso8601String();

    await _client.from('employee_private_data').insert(privateDataForInsert);
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
