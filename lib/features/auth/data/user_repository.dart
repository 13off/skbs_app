import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_profile.dart';

class UserRepository {
  static final _client = Supabase.instance.client;

  static AppUserProfile? _cachedProfile;
  static String? _cachedProfileUserId;

  static User? get currentUser => _client.auth.currentUser;

  static Session? get currentSession => _client.auth.currentSession;

  static AppUserProfile? get cachedProfile => _cachedProfile;

  static bool get mustSetPassword {
    final value = currentUser?.userMetadata?['must_set_password'];
    return value == true || value?.toString().toLowerCase() == 'true';
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
  }

  static Future<void> setActiveCompany(String companyId) async {
    await _client.rpc(
      'set_active_company',
      params: <String, dynamic>{'p_company_id': companyId.trim()},
    );
    clearProfileCache();
    await _client.auth.refreshSession();
  }

  static Future<void> signOut() async {
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

    final row = await _client
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
