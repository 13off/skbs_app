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
    await _client.auth.signInWithOtp(
      phone: phone,
      shouldCreateUser: true,
      channel: OtpChannel.sms,
      data: const <String, dynamic>{
        'role': 'employee',
        'must_set_password': false,
      },
    );
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
