import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import 'app_data_sync.dart';
import 'task_photo_models.dart';

class TaskPhotoRepository {
  static final _client = Supabase.instance.client;
  static const bucketName = 'task-photos';
  static const signedUrlLifetimeSeconds = 60 * 10;
  static const uploadConcurrency = 2;
  static const uploadTimeoutMs = 60 * 1000;
  static const webUploadMaxAttempts = 2;
  static const webUploadRetryDelay = Duration(milliseconds: 650);
  static const webUploadStallTimeout = Duration(seconds: 18);

  const TaskPhotoRepository._();

  static String safeStoragePath({
    required String taskId,
    required String photoStage,
    required TaskPhotoFile photo,
    required int index,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final extension = photo.extension.isEmpty ? 'jpg' : photo.extension;
    return '$taskId/$photoStage/${timestamp}_$index.$extension';
  }

  static Future<List<TaskPhotoData>> fetchPhotos(String taskId) async {
    final rows = await _client
        .from('task_photos')
        .select(
          'id, task_id, storage_path, original_name, photo_stage, created_at',
        )
        .eq('task_id', taskId)
        .order('created_at', ascending: false);

    return rows
        .map<TaskPhotoData>((row) => TaskPhotoData.fromSupabase(row))
        .toList();
  }

  static Future<List<TaskPhotoData>> uploadPhotos({
    required String taskId,
    required List<TaskPhotoFile> photos,
    required String photoStage,
    TaskPhotoUploadProgressCallback? onProgress,
  }) async {
    if (photos.isEmpty) return <TaskPhotoData>[];
    if (photoStage != 'before' && photoStage != 'after') {
      throw ArgumentError.value(photoStage, 'photoStage');
    }

    final uploadItems = List.generate(photos.length, (index) {
      final photo = photos[index];
      return (
        photo: photo,
        path: safeStoragePath(
          taskId: taskId,
          photoStage: photoStage,
          photo: photo,
          index: index + 1,
        ),
      );
    });
    final uploadedPaths = <String>[];
    final loadedBytesByPath = <String, int>{
      for (final item in uploadItems) item.path: 0,
    };
    final totalBytes = photos.fold<int>(
      0,
      (sum, photo) => sum + photo.bytes.length,
    );
    var completedFiles = 0;

    void emitProgress() {
      if (onProgress == null) return;
      final loadedBytes = loadedBytesByPath.values.fold<int>(
        0,
        (sum, loaded) => sum + loaded,
      );
      onProgress(
        TaskPhotoUploadProgress(
          loadedBytes: loadedBytes,
          totalBytes: totalBytes,
          completedFiles: completedFiles,
          totalFiles: photos.length,
        ),
      );
    }

    emitProgress();

    try {
      var nextUploadIndex = 0;
      final workerCount = uploadItems.length < uploadConcurrency
          ? uploadItems.length
          : uploadConcurrency;

      Future<void> runUploadWorker() async {
        while (true) {
          if (nextUploadIndex >= uploadItems.length) return;
          final item = uploadItems[nextUploadIndex];
          nextUploadIndex += 1;

          await _uploadPhotoBytes(
            path: item.path,
            photo: item.photo,
            onProgress: (loadedBytes) {
              loadedBytesByPath[item.path] = loadedBytes
                  .clamp(0, item.photo.bytes.length)
                  .toInt();
              emitProgress();
            },
          );
          loadedBytesByPath[item.path] = item.photo.bytes.length;
          uploadedPaths.add(item.path);
          completedFiles += 1;
          emitProgress();
        }
      }

      await Future.wait(
        List<Future<void>>.generate(workerCount, (_) => runUploadWorker()),
      );

      final rowsToInsert = uploadItems
          .map(
            (item) => <String, String>{
              'task_id': taskId,
              'storage_path': item.path,
              'original_name': item.photo.originalName,
              'photo_stage': photoStage,
            },
          )
          .toList();

      final rows = await _client
          .from('task_photos')
          .insert(rowsToInsert)
          .select(
            'id, task_id, storage_path, original_name, photo_stage, created_at',
          );

      return rows
          .map<TaskPhotoData>((row) => TaskPhotoData.fromSupabase(row))
          .toList();
    } catch (_) {
      await removeStoragePaths(uploadedPaths);
      rethrow;
    }
  }

  static Future<void> _uploadPhotoBytes({
    required String path,
    required TaskPhotoFile photo,
    required void Function(int loadedBytes) onProgress,
  }) async {
    if (!kIsWeb) {
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: FileOptions(
              contentType: photo.contentType,
              upsert: false,
            ),
          );
      onProgress(photo.bytes.length);
      return;
    }

    await _uploadPhotoBytesWeb(
      path: path,
      photo: photo,
      onProgress: onProgress,
    );
  }

  static Future<void> _uploadPhotoBytesWeb({
    required String path,
    required TaskPhotoFile photo,
    required void Function(int loadedBytes) onProgress,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= webUploadMaxAttempts; attempt++) {
      try {
        if (attempt > 1) onProgress(0);
        await _uploadPhotoBytesWebAttempt(
          path: path,
          photo: photo,
          onProgress: onProgress,
        );
        return;
      } catch (error) {
        lastError = error;

        if (attempt > 1 &&
            error is _TaskPhotoUploadHttpException &&
            error.status == 409) {
          // Первый запрос мог успеть сохраниться в Storage, а браузер потерял
          // только ответ. Повтор по тому же уникальному пути тогда получает
          // conflict — считаем исходную загрузку успешно завершённой.
          onProgress(photo.bytes.length);
          return;
        }

        if (attempt >= webUploadMaxAttempts ||
            !_isRetryableWebUploadError(error)) {
          rethrow;
        }

        await Future<void>.delayed(webUploadRetryDelay * attempt);
      }
    }

    throw lastError ?? Exception('Не удалось загрузить фотографию');
  }

  static bool _isRetryableWebUploadError(Object error) {
    if (error is TimeoutException) return true;
    if (error is _TaskPhotoNetworkException) return true;
    if (error is _TaskPhotoUploadHttpException) {
      return error.status == 408 ||
          error.status == 425 ||
          error.status == 429 ||
          error.status >= 500;
    }
    return false;
  }

  static Future<void> _uploadPhotoBytesWebAttempt({
    required String path,
    required TaskPhotoFile photo,
    required void Function(int loadedBytes) onProgress,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null || session.accessToken.isEmpty) {
      throw Exception('Сессия истекла. Войдите в приложение ещё раз.');
    }

    String? apiKey;
    for (final entry in _client.auth.headers.entries) {
      if (entry.key.toLowerCase() == 'apikey') {
        apiKey = entry.value;
        break;
      }
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Не удалось подготовить авторизацию для загрузки фото');
    }

    final cleanStorageUrl = _client.storage.url.replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final encodedObjectPath = <String>[
      bucketName,
      ...path.split('/'),
    ].map(Uri.encodeComponent).join('/');
    final request = html.HttpRequest();
    final completer = Completer<void>();
    Timer? stallTimer;

    void cancelStallTimer() {
      stallTimer?.cancel();
      stallTimer = null;
    }

    void armStallTimer() {
      if (completer.isCompleted) return;
      cancelStallTimer();
      stallTimer = Timer(webUploadStallTimeout, () {
        if (completer.isCompleted) return;
        completer.completeError(
          TimeoutException(
            'Передача фотографии остановилась. Повторяем загрузку.',
          ),
        );
        request.abort();
      });
    }

    request.open(
      'POST',
      '$cleanStorageUrl/object/$encodedObjectPath',
      async: true,
    );
    request.timeout = uploadTimeoutMs;
    request.setRequestHeader('apikey', apiKey);
    request.setRequestHeader(
      'Authorization',
      'Bearer ${session.accessToken}',
    );
    request.setRequestHeader('Content-Type', photo.contentType);
    request.setRequestHeader('Cache-Control', 'max-age=3600');

    request.upload.onProgress.listen((event) {
      final loaded = event.loaded ?? 0;
      final loadedBytes = loaded.toInt();
      onProgress(loadedBytes);
      if (loadedBytes >= photo.bytes.length) {
        cancelStallTimer();
      } else {
        armStallTimer();
      }
    });
    request.onLoad.listen((_) {
      cancelStallTimer();
      if (completer.isCompleted) return;
      final status = request.status ?? 0;
      if (status >= 200 && status < 300) {
        onProgress(photo.bytes.length);
        completer.complete();
        return;
      }
      final response = request.responseText?.trim();
      completer.completeError(
        _TaskPhotoUploadHttpException(
          status,
          response == null || response.isEmpty
              ? 'Storage вернул ошибку $status'
              : 'Storage вернул ошибку $status: $response',
        ),
      );
    });
    request.onError.listen((_) {
      cancelStallTimer();
      if (!completer.isCompleted) {
        completer.completeError(
          const _TaskPhotoNetworkException(
            'Сеть прервала загрузку фотографии. Повторяем загрузку.',
          ),
        );
      }
    });
    request.onTimeout.listen((_) {
      cancelStallTimer();
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException(
            'Фотография загружается слишком долго. Повторяем загрузку.',
          ),
        );
      }
    });

    request.send(photo.bytes);
    armStallTimer();
    try {
      await completer.future;
    } finally {
      cancelStallTimer();
    }
  }

  static Future<void> removeStoragePaths(Iterable<String> paths) async {
    final cleanPaths = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();
    if (cleanPaths.isEmpty) return;

    try {
      await _client.storage.from(bucketName).remove(cleanPaths);
    } catch (_) {
      // Служебная очистка удалит оставшиеся файлы.
    }
  }

  static Future<void> deletePhoto(TaskPhotoData photo) async {
    final deletedRows = await _client
        .from('task_photos')
        .delete()
        .eq('id', photo.id)
        .eq('task_id', photo.taskId)
        .select('id');

    if (deletedRows.isEmpty) {
      throw Exception('Фото уже удалено или редактирование закрыто');
    }

    await removeStoragePaths(<String>[photo.storagePath]);

    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.tasks},
      context: <String, dynamic>{
        'table': 'task_photos',
        'task_id': photo.taskId,
      },
    );
  }

  static Future<String> createSignedUrl(TaskPhotoData photo) {
    return _client.storage
        .from(bucketName)
        .createSignedUrl(photo.storagePath, signedUrlLifetimeSeconds);
  }
}

class _TaskPhotoUploadHttpException implements Exception {
  final int status;
  final String message;

  const _TaskPhotoUploadHttpException(this.status, this.message);

  @override
  String toString() => message;
}

class _TaskPhotoNetworkException implements Exception {
  final String message;

  const _TaskPhotoNetworkException(this.message);

  @override
  String toString() => message;
}
