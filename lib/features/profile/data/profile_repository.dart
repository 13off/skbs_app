import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/user_repository.dart';

class PersonalProfileData {
  final String fullName;
  final String phone;
  final String avatarPath;

  const PersonalProfileData({
    required this.fullName,
    required this.phone,
    required this.avatarPath,
  });

  static const PersonalProfileData empty = PersonalProfileData(
    fullName: '',
    phone: '',
    avatarPath: '',
  );

  factory PersonalProfileData.fromMap(Map<String, dynamic> map) {
    return PersonalProfileData(
      fullName: map['full_name']?.toString().trim() ?? '',
      phone: map['phone']?.toString().trim() ?? '',
      avatarPath: map['avatar_path']?.toString().trim() ?? '',
    );
  }
}

class ProfileRepository {
  static const String avatarBucket = 'profile-avatars';
  static const int maximumAvatarBytes = 5 * 1024 * 1024;

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<PersonalProfileData> fetchPersonalData() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    final row = await _client
        .from('user_profiles')
        .select('full_name, phone, avatar_path')
        .eq('id', user.id)
        .single();
    return PersonalProfileData.fromMap(row);
  }

  static Future<PersonalProfileData> savePersonalData({
    required String fullName,
    required String phone,
    Uint8List? avatarBytes,
    String avatarExtension = 'jpg',
    String avatarContentType = 'image/jpeg',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    final cleanName = _validateName(fullName);
    final cleanPhone = _validatePhone(phone);
    final current = await fetchPersonalData();
    var nextAvatarPath = current.avatarPath;
    String? uploadedPath;

    if (avatarBytes != null) {
      if (avatarBytes.isEmpty) throw Exception('Файл фотографии пустой');
      if (avatarBytes.length > maximumAvatarBytes) {
        throw Exception('Фотография должна быть не больше 5 МБ');
      }
      final cleanExtension = switch (avatarExtension.toLowerCase()) {
        'jpeg' => 'jpg',
        'jpg' || 'png' || 'webp' => avatarExtension.toLowerCase(),
        _ => 'jpg',
      };
      uploadedPath =
          '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$cleanExtension';
      await _client.storage.from(avatarBucket).uploadBinary(
            uploadedPath,
            avatarBytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: avatarContentType,
              cacheControl: '3600',
            ),
          );
      nextAvatarPath = uploadedPath;
    }

    try {
      await _updateProfile(
        fullName: cleanName,
        phone: cleanPhone,
        avatarPath: nextAvatarPath,
      );
    } catch (_) {
      if (uploadedPath != null) {
        try {
          await _client.storage.from(avatarBucket).remove(<String>[uploadedPath]);
        } catch (_) {
          // Не скрываем исходную ошибку сохранения профиля.
        }
      }
      rethrow;
    }

    if (uploadedPath != null &&
        current.avatarPath.isNotEmpty &&
        current.avatarPath != uploadedPath) {
      await _removeFileQuietly(current.avatarPath);
    }

    UserRepository.clearProfileCache();
    return PersonalProfileData(
      fullName: cleanName,
      phone: cleanPhone,
      avatarPath: nextAvatarPath,
    );
  }

  static Future<PersonalProfileData> removeAvatar({
    required String fullName,
    required String phone,
  }) async {
    final cleanName = _validateName(fullName);
    final cleanPhone = _validatePhone(phone);
    final current = await fetchPersonalData();

    await _updateProfile(
      fullName: cleanName,
      phone: cleanPhone,
      avatarPath: '',
    );
    if (current.avatarPath.isNotEmpty) {
      await _removeFileQuietly(current.avatarPath);
    }

    UserRepository.clearProfileCache();
    return PersonalProfileData(
      fullName: cleanName,
      phone: cleanPhone,
      avatarPath: '',
    );
  }

  static Future<void> _updateProfile({
    required String fullName,
    required String phone,
    required String avatarPath,
  }) {
    return _client.rpc(
      'update_current_user_profile',
      params: <String, dynamic>{
        'p_full_name': fullName,
        'p_phone': phone,
        'p_avatar_path': avatarPath,
      },
    );
  }

  static String _validateName(String value) {
    final clean = value.trim();
    if (clean.length < 2) throw Exception('Укажите ФИО');
    if (clean.length > 160) throw Exception('ФИО слишком длинное');
    return clean;
  }

  static String _validatePhone(String value) {
    final clean = value.trim();
    if (clean.length > 40) throw Exception('Номер телефона слишком длинный');
    return clean;
  }

  static Future<void> _removeFileQuietly(String path) async {
    try {
      await _client.storage.from(avatarBucket).remove(<String>[path]);
    } catch (_) {
      // Профиль уже обновлён. Старый файл можно подчистить позднее.
    }
  }

  static Future<String?> createAvatarUrl(String avatarPath) async {
    final cleanPath = avatarPath.trim();
    if (cleanPath.isEmpty) return null;
    return _client.storage.from(avatarBucket).createSignedUrl(cleanPath, 3600);
  }
}
