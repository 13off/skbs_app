import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_data_sync.dart';
import 'task_photo_models.dart';

class TaskPhotoRepository {
  static final _client = Supabase.instance.client;
  static const bucketName = 'task-photos';
  static const signedUrlLifetimeSeconds = 60 * 10;

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

    try {
      // Фото независимы друг от друга. Параллельная отправка заметно сокращает
      // ожидание после кнопки «Сохранить» при нескольких снимках.
      await Future.wait(
        uploadItems.map((item) async {
          await _client.storage.from(bucketName).uploadBinary(
                item.path,
                item.photo.bytes,
                fileOptions: FileOptions(
                  contentType: item.photo.contentType,
                  upsert: false,
                ),
              );
          uploadedPaths.add(item.path);
        }),
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
