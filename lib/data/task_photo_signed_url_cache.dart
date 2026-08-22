import 'task_photo_models.dart';
import 'task_photo_repository.dart';

class TaskPhotoSignedUrlCache {
  static const Duration cacheTtl = Duration(minutes: 8);

  static final Map<String, _TaskPhotoSignedUrlEntry> _entries =
      <String, _TaskPhotoSignedUrlEntry>{};
  static final Map<String, Future<String>> _requests =
      <String, Future<String>>{};

  const TaskPhotoSignedUrlCache._();

  static String _originalKey(TaskPhotoData photo) => photo.storagePath.trim();
  static String _previewKey(TaskPhotoData photo) =>
      photo.previewStoragePath.trim();

  static String? _cachedPath(String key) {
    if (key.isEmpty) return null;
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.createdAt) >= cacheTtl) {
      _entries.remove(key);
      return null;
    }
    return entry.url;
  }

  static String? cachedUrl(TaskPhotoData photo) =>
      _cachedPath(_originalKey(photo));

  static String? cachedPreviewUrl(TaskPhotoData photo) =>
      _cachedPath(_previewKey(photo));

  static Future<String> getSignedUrl(TaskPhotoData photo) {
    return _getSignedUrlForPath(_originalKey(photo));
  }

  static Future<String> getPreviewSignedUrl(TaskPhotoData photo) {
    return _getSignedUrlForPath(_previewKey(photo));
  }

  static Future<String> _getSignedUrlForPath(String key) {
    final cached = _cachedPath(key);
    if (cached != null) return Future<String>.value(cached);
    if (key.isEmpty) {
      return Future<String>.error(ArgumentError.value(key, 'storagePath'));
    }

    final running = _requests[key];
    if (running != null) return running;

    late final Future<String> request;
    request = TaskPhotoRepository.createSignedUrlForPath(key)
        .then((url) {
          _entries[key] = _TaskPhotoSignedUrlEntry(
            url: url,
            createdAt: DateTime.now(),
          );
          return url;
        })
        .whenComplete(() {
          if (identical(_requests[key], request)) _requests.remove(key);
        });
    _requests[key] = request;
    return request;
  }

  static Future<void> prewarmPreviews(Iterable<TaskPhotoData> photos) async {
    await Future.wait<void>(
      photos.map((photo) async {
        try {
          await getPreviewSignedUrl(photo);
        } catch (_) {
          // Preview warmup is best-effort.
        }
      }),
    );
  }

  static void evict(TaskPhotoData photo) {
    for (final key in <String>{_originalKey(photo), _previewKey(photo)}) {
      if (key.isEmpty) continue;
      _entries.remove(key);
      _requests.remove(key);
    }
  }

  static void clear() {
    _entries.clear();
    _requests.clear();
  }
}

class _TaskPhotoSignedUrlEntry {
  final String url;
  final DateTime createdAt;

  const _TaskPhotoSignedUrlEntry({required this.url, required this.createdAt});
}
