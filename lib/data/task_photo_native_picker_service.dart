import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'task_photo_models.dart';

class TaskPhotoNativePickerService {
  static const MethodChannel _channel = MethodChannel(
    'ru.appstroy.skbs/task_photos',
  );

  const TaskPhotoNativePickerService._();

  static Future<List<TaskPhotoFile>> pickPhotoFiles() async {
    final rows = await _channel.invokeListMethod<dynamic>(
      'pickPhotos',
      const <String, dynamic>{
        'maxDimension': 1440,
        'jpegQuality': 78,
      },
    );
    if (rows == null || rows.isEmpty) return <TaskPhotoFile>[];

    final photos = <TaskPhotoFile>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<dynamic, dynamic>.from(raw);
      final rawBytes = row['bytes'];
      final bytes = switch (rawBytes) {
        Uint8List value => value,
        ByteData value => value.buffer.asUint8List(),
        _ => null,
      };
      if (bytes == null || bytes.isEmpty) continue;

      final originalName = row['name']?.toString().trim();
      photos.add(
        TaskPhotoFile(
          originalName: originalName == null || originalName.isEmpty
              ? 'photo_${photos.length + 1}.jpg'
              : originalName,
          contentType: 'image/jpeg',
          extension: 'jpg',
          bytes: bytes,
        ),
      );
    }

    if (photos.isEmpty) {
      throw Exception('Не удалось подготовить выбранные фотографии');
    }
    return photos;
  }
}
