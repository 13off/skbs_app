import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/push_notification_service.dart';
import 'user_repository.dart';

class EmployeeMaxLoginStart {
  final String status;
  final String attemptToken;
  final String maxUrl;
  final DateTime? expiresAt;

  const EmployeeMaxLoginStart({
    required this.status,
    required this.attemptToken,
    required this.maxUrl,
    required this.expiresAt,
  });

  bool get needsInitialLink => status == 'link_required';
}

class EmployeeMaxLoginPoll {
  final String status;
  final String? error;

  const EmployeeMaxLoginPoll({required this.status, this.error});

  bool get signedIn => status == 'signed_in';
  bool get expired => status == 'expired';
}

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

  static Map<String, dynamic> _readFunctionData(
    FunctionResponse response, {
    required String fallbackError,
  }) {
    final raw = response.data;
    if (raw is! Map) throw AuthException(fallbackError);
    final data = Map<String, dynamic>.from(raw);
    if (data['ok'] != true) {
      final error = data['error']?.toString().trim() ?? '';
      throw AuthException(error.isEmpty ? fallbackError : error);
    }
    return data;
  }

  static Future<EmployeeMaxLoginStart> requestMaxLogin(String rawPhone) async {
    final phone = normalizeRussianPhone(rawPhone);
    UserRepository.clearProfileCache();
    final response = await _client.functions.invoke(
      'employee-max-login',
      body: <String, dynamic>{'action': 'request', 'phone': phone},
    );
    final data = _readFunctionData(
      response,
      fallbackError: 'Не удалось начать вход через MAX',
    );
    final attemptToken = data['attempt_token']?.toString().trim() ?? '';
    final maxUrl = data['max_url']?.toString().trim() ?? '';
    if (attemptToken.isEmpty || maxUrl.isEmpty) {
      throw const AuthException('MAX не вернул ссылку подтверждения');
    }
    return EmployeeMaxLoginStart(
      status: data['status']?.toString().trim() ?? 'waiting_max',
      attemptToken: attemptToken,
      maxUrl: maxUrl,
      expiresAt: DateTime.tryParse(data['expires_at']?.toString() ?? ''),
    );
  }

  static Future<EmployeeMaxLoginPoll> pollMaxLogin(
    String attemptToken,
  ) async {
    final response = await _client.functions.invoke(
      'employee-max-login',
      body: <String, dynamic>{
        'action': 'poll',
        'attempt_token': attemptToken,
      },
    );
    final raw = response.data;
    if (raw is! Map) {
      throw const AuthException('Не удалось проверить подтверждение MAX');
    }
    final data = Map<String, dynamic>.from(raw);
    final status = data['status']?.toString().trim() ?? '';
    if (data['ok'] != true) {
      final error = data['error']?.toString().trim() ?? '';
      if (status == 'expired') {
        return EmployeeMaxLoginPoll(status: status, error: error);
      }
      throw AuthException(
        error.isEmpty ? 'Не удалось проверить подтверждение MAX' : error,
      );
    }

    if (status == 'signed_in') {
      final rawSession = data['session'];
      if (rawSession is! Map) {
        throw const AuthException('MAX не вернул сессию сотрудника');
      }
      final session = Map<String, dynamic>.from(rawSession);
      final accessToken = session['access_token']?.toString().trim() ?? '';
      final refreshToken = session['refresh_token']?.toString().trim() ?? '';
      if (accessToken.isEmpty || refreshToken.isEmpty) {
        throw const AuthException('Сессия сотрудника неполная');
      }
      final authResponse = await _client.auth.setSession(
        refreshToken,
        accessToken: accessToken,
      );
      if (authResponse.session == null || authResponse.user == null) {
        throw const AuthException('Не удалось сохранить вход сотрудника');
      }
      UserRepository.clearProfileCache();
      unawaited(
        PushNotificationService.syncForCurrentSession(requestPermission: true),
      );
    }

    return EmployeeMaxLoginPoll(
      status: status.isEmpty ? 'waiting_max' : status,
      error: data['error']?.toString().trim(),
    );
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
