import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';

class EmployeeRepository {
  static final _client = Supabase.instance.client;

  static const List<String> baseObjects = ['Мурманск', 'Москва'];

  static String? cleanObjectName(String? objectName) {
    final clean = objectName?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
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
  }) async {
    final cleanObject = cleanObjectName(objectName);

    var rows = cleanObject == null
        ? await _client
              .from('employees')
              .select(
                'id, fio, position, phone, object_name, daily_rate, is_active, comment',
              )
        : await _client
              .from('employees')
              .select(
                'id, fio, position, phone, object_name, daily_rate, is_active, comment',
              )
              .eq('object_name', cleanObject);

    if (!includeFired) {
      rows = rows.where((row) {
        return row['is_active'] as bool? ?? true;
      }).toList();
    }

    final employees = rows.map<Employee>((row) {
      return Employee.fromSupabase(row);
    }).toList();

    return _sortEmployees(employees);
  }

  static Future<List<String>> fetchObjectNames() async {
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

    return result;
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
  }
}
