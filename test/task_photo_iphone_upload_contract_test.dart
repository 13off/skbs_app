import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('фото до и после используют раздельное состояние загрузки', () {
    final editor = File(
      'lib/screens/task_details/task_details_editor_screen.dart',
    ).readAsStringSync();
    final photoActions = File(
      'lib/screens/task_details/task_details_photo_actions.dart',
    ).readAsStringSync();

    expect(editor, contains('String? pickingPhotoStage'));
    expect(editor, isNot(contains('bool isPickingPhotos')));
    expect(photoActions, contains('pickingPhotoStage = photoStage'));
    expect(photoActions, contains('photoStage: photoStage'));
    expect(photoActions, contains('pickingPhotoStage == photoStage'));
  });

  test('iPhone HEIC и HEIF нормализуются в JPEG до storage upload', () {
    final picker = File(
      'lib/data/task_photo_browser_service.dart',
    ).readAsStringSync();
    final compression = File(
      'lib/data/image_compression_service.dart',
    ).readAsStringSync();

    expect(picker, contains("'image/*,.heic,.heif'"));
    expect(picker, contains("'image/heic'"));
    expect(picker, contains("'image/heif'"));
    expect(picker, contains('requiresJpegNormalization'));
    expect(picker, contains('forceJpeg: forceJpeg'));
    expect(picker, contains('reader.onError'));
    expect(picker, contains('fileReadTimeout'));

    expect(compression, contains('bool forceJpeg = false'));
    expect(compression, contains("contentType: 'image/jpeg'"));
    expect(compression, contains("extension: 'jpg'"));
    expect(compression, contains('imageDecodeTimeout'));
    expect(compression, contains('blobReadTimeout'));
  });

  test('пикер и экран поддерживают несколько фотографий за один выбор', () {
    final picker = File(
      'lib/data/task_photo_browser_service.dart',
    ).readAsStringSync();
    final photoActions = File(
      'lib/screens/task_details/task_details_photo_actions.dart',
    ).readAsStringSync();

    expect(picker, contains('..multiple = true'));
    expect(picker, contains('prepareConcurrency = 2'));
    expect(picker, contains('Future.wait'));
    expect(photoActions, contains("'Добавить фотографии'"));
    expect(photoActions, contains("'Добавить ещё фотографии'"));
    expect(photoActions, contains(r'Добавлено фотографий: $count'));
  });

  test('процент загрузки считается по реально отправленным байтам', () {
    final models = File('lib/data/task_photo_models.dart').readAsStringSync();
    final repository = File(
      'lib/data/task_photo_repository.dart',
    ).readAsStringSync();
    final photoActions = File(
      'lib/screens/task_details/task_details_photo_actions.dart',
    ).readAsStringSync();

    expect(models, contains('loadedBytes'));
    expect(models, contains('totalBytes'));
    expect(models, contains('loadedBytes / totalBytes'));
    expect(repository, contains('request.upload.onProgress'));
    expect(repository, contains('final loaded = event.loaded ?? 0;'));
    expect(repository, contains('onProgress(loaded.toInt())'));
    expect(repository, contains("request.open(\n      'POST'"));
    expect(repository, contains("request.setRequestHeader('Content-Type'"));
    expect(photoActions, contains(r"'Загрузка ${progress.percent}%"));
    expect(photoActions, contains('LinearProgressIndicator'));
    expect(photoActions, contains('value: progress.fraction'));
  });
}
