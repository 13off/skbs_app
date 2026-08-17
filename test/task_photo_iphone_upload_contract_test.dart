import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('фото до и после используют раздельное состояние загрузки', () {
    final editor = File(
      'lib/screens/task_details/task_details_editor_screen.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/screens/task_details/task_details_actions.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/task_details/task_details_sections.dart',
    ).readAsStringSync();

    expect(editor, contains('String? pickingPhotoStage'));
    expect(editor, isNot(contains('bool isPickingPhotos')));
    expect(actions, contains('pickingPhotoStage = photoStage'));
    expect(actions, contains('photoStage: photoStage'));
    expect(actions, contains('pickingPhotoStage == photoStage'));
    expect(sections, contains('pickingPhotoStage == photoStage'));
    expect(sections, contains('isThisStagePicking'));
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
}
