import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_profile.dart';

class UserRepository {
  static final _client = Supabase.instance.client;

  static User? get currentUser {
    return _client.auth.currentUser;
  }

  static Session? get currentSession {
    return _client.auth.currentSession;
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static Future<AppUserProfile?> fetchCurrentProfile() async {
    final user = currentUser;

    if (user == null) return null;

    final row = await _client
        .from('user_profiles')
        .select('id, email, full_name, role, object_name, is_active')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;

    return AppUserProfile.fromMap(row);
  }
}
