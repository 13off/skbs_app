import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../../services/push_notification_service.dart';
import '../models/app_user_profile.dart';

class UserRepository {
  static final _client = Supabase.instance.client;

  static AppUserProfile? _cachedProfile;
  static String? _cachedProfileUserId;
  static Future<bool>? _pendingInvitationApplication;
  static String? _consumedInvitationCompanyId;

  static const String _invitationCompanyParameter = 'companyInvite';
  static const String _fallbackWebAppUrl =
      'https://13off.github.io/appstroy-web/';

  static User? get currentUser => _client.auth.currentUser;

  static Session? get currentSession => _client.auth.currentSession;

  static AppUserProfile? get cachedProfile => _cachedProfile;

  static bool get mustSetPassword {
    final value = currentUser?.userMetadata?['must_set_password'];
    return value == true || value?.toString().toLowerCase() == 'true';
  }

  static String buildInvitationRedirectUrl(String companyId) {
    final cleanCompanyId = companyId.trim();
    final current = Uri.base;
    final canUseCurrent = kIsWeb &&
        (current.scheme == 'https' || current.scheme == 'http') &&
        current.host.isNotEmpty;
    final base = canUseCurrent ? current : Uri.parse(_fallbackWebAppUrl);

    return base
        .replace(
          queryParameters: <String, String>{
            _invitationCompanyParameter: cleanCompanyId,
          },
          fragment: '',
        )
        .toString();
  }

  static String? get pendingInvitationCompanyId {
    final companyId = Uri.base.queryParameters[_invitationCompanyParameter]
        ?.trim();
    if (companyId == null || companyId.isEmpty) return null;
    if (companyId == _consumedInvitationCompanyId) return null;
    return companyId;
  }

  static Future<bool> applyPendingInvitationCompany() {
    final running = _pendingInvitationApplication;
    if (running != null) return running;

    late final Future<bool> future;
    future = _applyPendingInvitationCompany().whenComplete(() {
      if (identical(_pendingInvitationApplication, future)) {
        _pendingInvitationApplication = null;
      }
    });
    _pendingInvitationApplication = future;
    return future;
  }

  static Future<bool> _applyPendingInvitationCompany() async {
    final companyId = pendingInvitationCompanyId;
    if (companyId == null) return false;

    await setActiveCompany(companyId);
    await _client.rpc('accept_current_company_invitation');

    _consumedInvitationCompanyId = companyId;
    _removeInvitationCompanyFromBrowserUrl();
    return true;
  }

  static void _removeInvitationCompanyFromBrowserUrl() {
    if (!kIsWeb) return;

    final current = Uri.base;
    final parameters = Map<String, String>.from(current.queryParameters)
      ..remove(_invitationCompanyParameter);
    final cleaned = current.replace(queryParameters: parameters, fragment: '');
    html.window.history.replaceState(
      null,
      html.document.title,
      cleaned.toString(),
    );
  }

  static void clearProfileCache() {
    _cachedProfile = null;
    _cachedProfileUserId = null;
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    clearProfileCache();

    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.session == null || response.user == null) {
      throw const AuthException('Не удалось создать сессию пользователя');
    }

    unawaited(
      PushNotificationService.syncForCurrentSession(requestPermission: true),
    );
  }

  static Future<bool> signUpCompany({
    required String companyName,
    required String fullName,
    required String email,
    required String password,
  }) async {
    clearProfileCache();

    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: <String, dynamic>{
        'company_name': companyName.trim(),
        'full_name': fullName.trim(),
        'must_set_password': false,
      },
    );

    if (response.user == null) {
      throw const AuthException('Не удалось зарегистрировать пользователя');
    }

    if (response.session == null) return false;

    await createCompanyProfile(
      companyName: companyName,
      fullName: fullName,
    );
    unawaited(
      PushNotificationService.syncForCurrentSession(requestPermission: true),
    );
    return true;
  }

  static Future<void> createCompanyProfile({
    required String companyName,
    required String fullName,
  }) async {
    await _client.rpc(
      'create_company_for_current_user',
      params: <String, dynamic>{
        'p_company_name': companyName.trim(),
        'p_full_name': fullName.trim(),
      },
    );
    clearProfileCache();
  }

  static Future<void> setInvitationPassword(String password) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: password,
        data: const <String, dynamic>{'must_set_password': false},
      ),
    );
    await _client.rpc('accept_current_company_invitation');
    clearProfileCache();
    await _client.auth.refreshSession();
    unawaited(
      PushNotificationService.syncForCurrentSession(requestPermission: true),
    );
  }

  static Future<void> setActiveCompany(String companyId) async {
    await _client.rpc(
      'set_active_company',
      params: <String, dynamic>{'p_company_id': companyId.trim()},
    );
    clearProfileCache();
    await _client.auth.refreshSession();
    unawaited(PushNotificationService.syncForCurrentSession());
  }

  static Future<void> signOut() async {
    await PushNotificationService.unregisterCurrentDevice();
    _consumedInvitationCompanyId = null;
    _pendingInvitationApplication = null;
    clearProfileCache();
    await _client.auth.signOut();
  }

  static Future<AppUserProfile?> fetchCurrentProfile({
    bool forceRefresh = false,
  }) async {
    final user = currentUser;

    if (user == null) {
      clearProfileCache();
      return null;
    }

    if (!forceRefresh &&
        _cachedProfile != null &&
        _cachedProfileUserId == user.id) {
      return _cachedProfile;
    }

    var row = await _client
        .from('user_profiles')
        .select(
          'id, email, full_name, role, object_name, is_active, active_company_id',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      clearProfileCache();
      return null;
    }

    final activeCompanyId = row['active_company_id']?.toString().trim() ?? '';
    if (activeCompanyId.isEmpty) {
      final membership = await _client
          .from('company_memberships')
          .select('company_id')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('created_at')
          .limit(1)
          .maybeSingle();
      final fallbackCompanyId =
          membership?['company_id']?.toString().trim() ?? '';

      if (fallbackCompanyId.isNotEmpty) {
        await _client.rpc(
          'set_active_company',
          params: <String, dynamic>{'p_company_id': fallbackCompanyId},
        );
        await _client.auth.refreshSession();
        row = await _client
            .from('user_profiles')
            .select(
              'id, email, full_name, role, object_name, is_active, active_company_id',
            )
            .eq('id', user.id)
            .maybeSingle();
        if (row == null) {
          clearProfileCache();
          return null;
        }
      }
    }

    final profile = AppUserProfile.fromMap(row);

    _cachedProfile = profile;
    _cachedProfileUserId = user.id;

    return profile;
  }

  static Future<String> currentActorName() async {
    final profile = await fetchCurrentProfile();
    final fullName = profile?.fullName.trim() ?? '';

    if (fullName.isNotEmpty) return fullName;

    final email = currentUser?.email?.trim() ?? '';
    if (email.isNotEmpty) return email;

    return 'Пользователь';
  }

  static Future<String?> currentObjectName() async {
    final profile = await fetchCurrentProfile();
    final objectName = profile?.objectName.trim() ?? '';

    return objectName.isEmpty ? null : objectName;
  }
}
