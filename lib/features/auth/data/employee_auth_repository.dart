import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/push_notification_service.dart';
import 'user_repository.dart';

class EmployeeAuthRepository {
  static final _client = Supabase.instance.client;

  static String normalizeRussianPhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+7$digits';
    if (digits.length == 11 && digits.startsWith('8')) {
      return '+7${digits.substring(1)}';
    }
    if (digits.length == 11 && digits.startsWith('7')) return '+$digits';
    throw const AuthException('Некорректный номер телефона');
  }

  static Future<void> requestCode(String rawPhone) async {
    final phone = normalizeRussianPhone(rawPhone);
    UserRepository.clearProfileCache();

    final response = await _client.functions.invoke(
      'request-employee-otp',
      body: <String, dynamic>{'phone': phone},
    );
    final raw = response.data;
    if (raw is! Map) {
      throw const AuthException('Не удалось проверить доступ сотрудника');
    }
    final data = Map<String, dynamic>.from(raw);
    final error = data['error']?.toString().trim() ?? '';
    if (data['ok'] != true) {
      throw AuthException(
        error.isEmpty ? 'Этот номер не подключён к кабинету сотрудника' : error,
      );
    }
  }

  static Future<void> verifyCode({
    required String rawPhone,
    required String code,
  }) async {
    final phone = normalizeRussianPhone(rawPhone);
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: code.trim(),
      type: OtpType.sms,
    );

    if (response.session == null || response.user == null) {
      throw const AuthException('Не удалось создать сессию сотрудника');
    }

    UserRepository.clearProfileCache();
    unawaited(
      PushNotificationService.syncForCurrentSession(requestPermission: true),
    );
  }
}
