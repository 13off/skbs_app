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

    final cleanName = fullName.trim();
    final cleanPhone = phone.trim();
    if (cleanName.length < 2) {
      throw Exception('Укажите ФИО');
    }
    if (cleanName.length > 160) {
      throw Exception('ФИО слишком длинное');
    }
    if (cleanPhone.length > 40) {
      throw Exception('Номер телефона слишком длинный');
    }

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
      await _client.rpc(
        'update_current_user_profile',
        params: <String, dynamic>{
          'p_full_name': cleanName,
          'p_phone': cleanPhone,
          'p_avatar_path': nextAvatarPath,
        },
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
      try {
        await _client.storage
            .from(avatarBucket)
            .remove(<String>[current.avatarPath]);
      } catch (_) {
        // Новая фотография уже сохранена; старый файл можно удалить позднее.
      }
    }

    UserRepository.clearProfileCache();
    return PersonalProfileData(
      fullName: cleanName,
      phone: cleanPhone,
      avatarPath: nextAvatarPath,
    );
  }

  static Future<String?> createAvatarUrl(String avatarPath) async {
    final cleanPath = avatarPath.trim();
    if (cleanPath.isEmpty) return null;
    return _client.storage.from(avatarBucket).createSignedUrl(cleanPath, 3600);
  }
}
