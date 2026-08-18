import 'task_photo_models.dart';
import 'task_photo_repository.dart';

class TaskPhotoSignedUrlCache {
  static const Duration cacheTtl = Duration(minutes: 8);

  static final Map<String, _TaskPhotoSignedUrlEntry> _entries =
      <String, _TaskPhotoSignedUrlEntry>{};
  static final Map<String, Future<String>> _requests = <String, Future<String>>{};

  const TaskPhotoSignedUrlCache._();

  static String _key(TaskPhotoData photo) => photo.storagePath.trim();

  static String? cachedUrl(TaskPhotoData photo) {
    final key = _key(photo);
    if (key.isEmpty) return null;
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.createdAt) >= cacheTtl) {
      _entries.remove(key);
      return null;
    }
    return entry.url;
  }

  static Future<String> getSignedUrl(TaskPhotoData photo) {
    final cached = cachedUrl(photo);
    if (cached != null) return Future<String>.value(cached);

    final key = _key(photo);
    if (key.isEmpty) {
      return Future<String>.error(
        ArgumentError.value(photo.storagePath, 'storagePath'),
      );
    }

    final running = _requests[key];
    if (running != null) return running;

    late final Future<String> request;
    request = TaskPhotoRepository.createSignedUrl(photo).then((url) {
      _entries[key] = _TaskPhotoSignedUrlEntry(
        url: url,
        createdAt: DateTime.now(),
      );
      return url;
    }).whenComplete(() {
      if (identical(_requests[key], request)) {
        _requests.remove(key);
      }
    });
    _requests[key] = request;
    return request;
  }

  static void evict(TaskPhotoData photo) {
    final key = _key(photo);
    if (key.isEmpty) return;
    _entries.remove(key);
    _requests.remove(key);
  }

  static void clear() {
    _entries.clear();
    _requests.clear();
  }
}

class _TaskPhotoSignedUrlEntry {
  final String url;
  final DateTime createdAt;

  const _TaskPhotoSignedUrlEntry({
    required this.url,
    required this.createdAt,
  });
}
