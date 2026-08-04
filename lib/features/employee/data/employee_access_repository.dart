import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeAccessState {
  final bool connected;
  final bool active;
  final String phone;
  final bool maxConnected;
  final bool maxReady;
  final String maxUsername;
  final String maxConnectUrl;
  final String maxConnectCode;
  final DateTime? maxConnectExpiresAt;

  const EmployeeAccessState({
    required this.connected,
    required this.active,
    required this.phone,
    this.maxConnected = false,
    this.maxReady = false,
    this.maxUsername = '',
    this.maxConnectUrl = '',
    this.maxConnectCode = '',
    this.maxConnectExpiresAt,
  });

  factory EmployeeAccessState.fromAccessJson(Map<String, dynamic> json) {
    return EmployeeAccessState(
      connected: json['connected'] as bool? ?? false,
      active: json['active'] as bool? ?? false,
      phone: json['phone']?.toString().trim() ?? '',
    );
  }

  EmployeeAccessState withMaxJson(Map<String, dynamic> json) {
    return EmployeeAccessState(
      connected: connected,
      active: active,
      phone: phone,
      maxConnected: json['max_connected'] as bool? ?? false,
      maxReady: json['max_ready'] as bool? ?? active,
      maxUsername: json['max_username']?.toString().trim() ?? '',
      maxConnectUrl: json['max_connect_url']?.toString().trim() ?? '',
      maxConnectCode: json['max_connect_code']?.toString().trim() ?? '',
      maxConnectExpiresAt: DateTime.tryParse(
        json['max_connect_expires_at']?.toString() ?? '',
      ),
    );
  }
}

class EmployeeAccessRepository {
  static final _client = Supabase.instance.client;

  static Future<EmployeeAccessState> fetchStatus(String employeeId) async {
    final access = await _invokeAccess(
      action: 'status',
      employeeId: employeeId,
    );
    final max = await _invokeMax(action: 'status', employeeId: employeeId);
    return access.withMaxJson(max);
  }

  static Future<EmployeeAccessState> enable(String employeeId) async {
    final access = await _invokeAccess(
      action: 'enable',
      employeeId: employeeId,
    );
    final max = await _invokeMax(action: 'prepare', employeeId: employeeId);
    return access.withMaxJson(max);
  }

  static Future<EmployeeAccessState> disable(String employeeId) async {
    final access = await _invokeAccess(
      action: 'disable',
      employeeId: employeeId,
    );
    final max = await _invokeMax(action: 'disable', employeeId: employeeId);
    return access.withMaxJson(max);
  }

  static Future<EmployeeAccessState> prepareMax(String employeeId) async {
    final access = await _invokeAccess(
      action: 'status',
      employeeId: employeeId,
    );
    if (!access.active) {
      throw Exception('Сначала откройте сотруднику доступ в приложение');
    }
    final max = await _invokeMax(action: 'prepare', employeeId: employeeId);
    return access.withMaxJson(max);
  }

  static Future<EmployeeAccessState> _invokeAccess({
    required String action,
    required String employeeId,
  }) async {
    final data = await _invoke(
      functionName: 'manage-employee-access',
      action: action,
      employeeId: employeeId,
      fallbackError: 'Не удалось изменить доступ сотрудника',
    );
    return EmployeeAccessState.fromAccessJson(data);
  }

  static Future<Map<String, dynamic>> _invokeMax({
    required String action,
    required String employeeId,
  }) {
    return _invoke(
      functionName: 'manage-employee-max',
      action: action,
      employeeId: employeeId,
      fallbackError: 'Не удалось настроить MAX сотрудника',
    );
  }

  static Future<Map<String, dynamic>> _invoke({
    required String functionName,
    required String action,
    required String employeeId,
    required String fallbackError,
  }) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) {
      throw Exception('Не найден ID сотрудника');
    }

    try {
      final response = await _client.functions.invoke(
        functionName,
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
      return data;
    } catch (error) {
      final text = error.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(text.isEmpty ? fallbackError : text);
    }
  }
}
