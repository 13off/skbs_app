import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileAvatarService {
  ProfileAvatarService._();

  static const String bucketName = 'profile-avatars';
  static const Duration _cacheTtl = Duration(minutes: 50);
  static final Map<String, _AvatarUrlCacheEntry> _cache =
      <String, _AvatarUrlCacheEntry>{};
  static final Map<String, Future<String?>> _inFlight =
      <String, Future<String?>>{};

  static Future<String?> signedUrl(String? avatarPath) async {
    final path = avatarPath?.trim() ?? '';
    if (path.isEmpty) return null;

    final cached = _cache[path];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheTtl) {
      return cached.url;
    }

    final running = _inFlight[path];
    if (running != null) return running;

    final request = _load(path);
    _inFlight[path] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight[path], request)) _inFlight.remove(path);
    }
  }

  static Future<String?> _load(String path) async {
    try {
      final url = await Supabase.instance.client.storage
          .from(bucketName)
          .createSignedUrl(path, 3600);
      final clean = url.trim();
      if (clean.isEmpty) return null;
      _cache[path] = _AvatarUrlCacheEntry(url: clean, createdAt: DateTime.now());
      return clean;
    } catch (_) {
      return null;
    }
  }

  static void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}

class _AvatarUrlCacheEntry {
  final String url;
  final DateTime createdAt;

  const _AvatarUrlCacheEntry({required this.url, required this.createdAt});
}
