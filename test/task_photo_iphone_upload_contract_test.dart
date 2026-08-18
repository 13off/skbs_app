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

  test('web iPhone HEIC и HEIF нормализуются в JPEG до storage upload', () {
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

  test('Android и iOS используют нативный picker, а html остаётся только web', () {
    final picker = File(
      'lib/data/task_photo_browser_service.dart',
    ).readAsStringSync();
    final nativePicker = File(
      'lib/data/task_photo_native_picker_service.dart',
    ).readAsStringSync();
    final android = File(
      'android/app/src/main/kotlin/ru/appstroy/skbs/MainActivity.kt',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(picker, contains('if (!kIsWeb)'));
    expect(
      picker,
      contains('TaskPhotoNativePickerService.pickPhotoFiles()'),
    );
    expect(picker.indexOf('if (!kIsWeb)'), lessThan(picker.indexOf('FileUploadInputElement')));
    expect(nativePicker, contains("'ru.appstroy.skbs/task_photos'"));
    expect(nativePicker, contains("'pickPhotos'"));
    expect(nativePicker, contains("contentType: 'image/jpeg'"));

    expect(android, contains('TASK_PHOTO_CHANNEL'));
    expect(android, contains('Intent.ACTION_OPEN_DOCUMENT'));
    expect(android, contains('Intent.EXTRA_ALLOW_MULTIPLE'));
    expect(android, contains('Bitmap.CompressFormat.JPEG'));
    expect(android, contains('"contentType" to "image/jpeg"'));

    expect(ios, contains('import PhotosUI'));
    expect(ios, contains('PHPickerConfiguration'));
    expect(ios, contains('configuration.selectionLimit = 0'));
    expect(ios, contains('normalized.jpegData'));
    expect(ios, contains('FlutterStandardTypedData(bytes: data)'));
  });

  test('iOS PHPicker ищет окно SceneDelegate, а не только AppDelegate.window', () {
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();

    expect(info, contains(r'$(PRODUCT_MODULE_NAME).SceneDelegate'));
    expect(ios, contains('UIApplication.shared.connectedScenes'));
    expect(ios, contains(r'$0 as? UIWindowScene'));
    expect(ios, contains('.foregroundActive'));
    expect(ios, contains('.foregroundInactive'));
    expect(ios, contains(r'$0.isKeyWindow'));
    expect(ios, contains('activeWindow()?.rootViewController'));
    expect(ios, contains('if !Thread.isMainThread'));
    expect(ios, contains('DispatchQueue.main.async'));
  });

  test('процент web загрузки считается по реально отправленным байтам', () {
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
    expect(repository, contains('onProgress(loadedBytes)'));
    expect(repository, contains("request.open(\n      'POST'"));
    expect(repository, contains("request.setRequestHeader('Content-Type'"));
    expect(photoActions, contains(r"'Загрузка ${progress.percent}%"));
    expect(photoActions, contains('LinearProgressIndicator'));
    expect(photoActions, contains('value: progress.fraction'));
  });

  test('два upload-слота работают как живая очередь и не ждут медленную пару', () {
    final repository = File(
      'lib/data/task_photo_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('uploadConcurrency = 2'));
    expect(repository, contains('runUploadWorker'));
    expect(repository, contains('nextUploadIndex'));
    expect(repository, contains('List<Future<void>>.generate(workerCount'));
    expect(repository, isNot(contains('batch = uploadItems.sublist')));
  });

  test('зависший web upload повторяет только один файл без изменения RLS', () {
    final repository = File(
      'lib/data/task_photo_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('webUploadMaxAttempts = 2'));
    expect(repository, contains('webUploadStallTimeout'));
    expect(repository, contains('request.abort()'));
    expect(repository, contains('_isRetryableWebUploadError'));
    expect(repository, contains('error.status == 409'));
    expect(repository, contains('if (attempt > 1) onProgress(0)'));
    expect(repository, isNot(contains("setRequestHeader('x-upsert'")));
  });
}
