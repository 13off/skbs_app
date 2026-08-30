import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_profile.dart';

class OfflineProfileStore {
  OfflineProfileStore._();

  static const String _prefix = 'appstroy_auth_profile_v1';

  static String _key(String userId) => '$_prefix::${userId.trim()}';

  static Future<void> save(AppUserProfile profile) async {
    final userId = profile.id.trim();
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode(<String, dynamic>{
        'id': profile.id,
        'email': profile.email,
        'full_name': profile.fullName,
        'phone': profile.phone,
        'avatar_path': profile.avatarPath,
        'role': profile.actualRole,
        'profession': profile.profession,
        'object_name': profile.objectName,
        'active_company_id': profile.activeCompanyId,
        'is_active': profile.isActive,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  static Future<AppUserProfile?> readForCurrentSession() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return read(user.id);
  }

  static Future<AppUserProfile?> read(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(cleanUserId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final row = Map<String, dynamic>.from(decoded);
      if ((row['id']?.toString().trim() ?? '') != cleanUserId) return null;
      return AppUserProfile.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(cleanUserId));
  }
}
