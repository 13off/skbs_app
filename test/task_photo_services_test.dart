import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/data/task_photo_browser_service.dart';
import 'package:skbs_app/data/task_photo_models.dart';
import 'package:skbs_app/data/task_photo_repository.dart';

void main() {
  test('TaskRepository не содержит браузерную и storage-реализацию', () {
    final taskRepository = File(
      'lib/data/task_repository.dart',
    ).readAsStringSync();
    final browserService = File(
      'lib/data/task_photo_browser_service.dart',
    ).readAsStringSync();
    final photoRepository = File(
      'lib/data/task_photo_repository.dart',
    ).readAsStringSync();

    expect(taskRepository, isNot(contains('universal_html')));
    expect(taskRepository, isNot(contains('FileUploadInputElement')));
    expect(taskRepository, isNot(contains('ImageCompressionService')));
    expect(taskRepository, isNot(contains(".from('task_photos')")));
    expect(taskRepository, contains("export 'task_photo_models.dart';"));
    expect(
      taskRepository,
      contains('TaskPhotoBrowserService.pickPhotoFiles()'),
    );
    expect(taskRepository, contains('TaskPhotoRepository.uploadPhotos('));
    expect(browserService, contains('FileUploadInputElement'));
    expect(browserService, contains('ImageCompressionService'));
    expect(photoRepository, contains(".from('task_photos')"));
    expect(photoRepository, contains("bucketName = 'task-photos'"));
  });

  test('браузерный сервис принимает только поддерживаемые изображения', () {
    expect(TaskPhotoBrowserService.extensionFromFileName('before.JPG'), 'jpg');
    expect(TaskPhotoBrowserService.extensionFromFileName('after.webp'), 'webp');
    expect(TaskPhotoBrowserService.extensionFromFileName('scan.png'), 'png');
    expect(TaskPhotoBrowserService.extensionFromFileName('document.pdf'), '');
    expect(TaskPhotoBrowserService.extensionFromFileName('no_extension'), '');
  });

  test('результат FileReader безопасно приводится к байтам', () {
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    expect(TaskPhotoBrowserService.bytesFromReaderResult(bytes), bytes);

    final buffer = Uint8List.fromList(<int>[4, 5, 6]).buffer;
    expect(
      TaskPhotoBrowserService.bytesFromReaderResult(buffer),
      <int>[4, 5, 6],
    );

    expect(
      () => TaskPhotoBrowserService.bytesFromReaderResult('invalid'),
      throwsException,
    );
  });

  test('путь фотографии в Storage формируется предсказуемо', () {
    final photo = TaskPhotoFile(
      originalName: 'photo.png',
      contentType: 'image/png',
      extension: 'png',
      bytes: Uint8List(0),
    );

    final path = TaskPhotoRepository.safeStoragePath(
      taskId: 'task-1',
      photoStage: 'before',
      photo: photo,
      index: 2,
      now: DateTime.fromMillisecondsSinceEpoch(123456),
    );

    expect(path, 'task-1/before/123456_2.png');
  });

  test('модель фотографии сохраняет прежний Supabase-контракт', () {
    final photo = TaskPhotoData.fromSupabase(<String, dynamic>{
      'id': 'photo-1',
      'task_id': 'task-1',
      'storage_path': 'task-1/after/photo.jpg',
      'original_name': 'photo.jpg',
      'photo_stage': 'after',
      'created_at': '2026-07-20T12:00:00Z',
    });

    expect(photo.id, 'photo-1');
    expect(photo.taskId, 'task-1');
    expect(photo.isAfter, isTrue);
    expect(photo.isBefore, isFalse);
  });
}
