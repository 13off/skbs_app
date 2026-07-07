import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_profile.dart';

class UserRepository {
  static final _client = Supabase.instance.client;

  static AppUserProfile? _cachedProfile;
  static String? _cachedProfileUserId;

  static User? get currentUser {
    return _client.auth.currentUser;
  }

  static Session? get currentSession {
    return _client.auth.currentSession;
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

    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
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
        .select('id, email, full_name, role, object_name, is_active')
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
}
