import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeAccessState {
  final bool connected;
  final bool active;
  final String phone;

  const EmployeeAccessState({
    required this.connected,
    required this.active,
    required this.phone,
  });

  factory EmployeeAccessState.fromJson(Map<String, dynamic> json) {
    return EmployeeAccessState(
      connected: json['connected'] as bool? ?? false,
      active: json['active'] as bool? ?? false,
      phone: json['phone']?.toString().trim() ?? '',
    );
  }
}

class EmployeeAccessRepository {
  static final _client = Supabase.instance.client;

  static Future<EmployeeAccessState> fetchStatus(String employeeId) {
    return _invoke(action: 'status', employeeId: employeeId);
  }

  static Future<EmployeeAccessState> enable(String employeeId) {
    return _invoke(action: 'enable', employeeId: employeeId);
  }

  static Future<EmployeeAccessState> disable(String employeeId) {
    return _invoke(action: 'disable', employeeId: employeeId);
  }

  static Future<EmployeeAccessState> _invoke({
    required String action,
    required String employeeId,
  }) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) {
      throw Exception('Не найден ID сотрудника');
    }

    try {
      final response = await _client.functions.invoke(
        'manage-employee-access',
        body: <String, dynamic>{
          'action': action,
          'employee_id': cleanEmployeeId,
        },
      );
      final raw = response.data;
      if (raw is! Map) {
        throw Exception('Сервис доступа вернул некорректный ответ');
      }
      final data = Map<String, dynamic>.from(raw);
      final error = data['error']?.toString().trim() ?? '';
      if (error.isNotEmpty) throw Exception(error);
      return EmployeeAccessState.fromJson(data);
    } catch (error) {
      final text = error.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(
        text.isEmpty ? 'Не удалось изменить доступ сотрудника' : text,
      );
    }
  }
}
