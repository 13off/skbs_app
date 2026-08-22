import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native не вызывает html.window при открытии URL', () {
    final source = File(
      'lib/data/task_photo_browser_service.dart',
    ).readAsStringSync();

    expect(source, contains('if (kIsWeb)'));
    expect(source, contains("html.window.open(url, '_blank')"));
    expect(source, contains('launchUrl(uri, mode: LaunchMode.externalApplication)'));
    expect(
      source.indexOf('if (kIsWeb)'),
      lessThan(source.indexOf("html.window.open(url, '_blank')")),
    );
  });

  test('экран задачи открывает оригинал фото внутри приложения с zoom', () {
    final viewer = File(
      'lib/screens/task_details/task_details_photo_viewer.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/task_details/task_details_sections.dart',
    ).readAsStringSync();

    expect(viewer, contains('Future<void> openPhotoInApp('));
    expect(viewer, contains('showGeneralDialog<void>'));
    expect(viewer, contains('InteractiveViewer('));
    expect(viewer, contains('maxScale: 5'));
    expect(viewer, contains('Image.network('));
    expect(viewer, contains('TaskPhotoSignedUrlCache.getSignedUrl(photo)'));
    expect(sections, contains('onTap: () => openPhotoInApp(photo)'));
    expect(viewer, isNot(contains('html.window.open')));
  });

  test('original and preview signed URLs are cached independently', () {
    final cache = File(
      'lib/data/task_photo_signed_url_cache.dart',
    ).readAsStringSync();
    final loading = File(
      'lib/screens/task_details/task_details_loading.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/task_details/task_details_sections.dart',
    ).readAsStringSync();

    expect(cache, contains('cacheTtl = Duration(minutes: 8)'));
    expect(cache, contains('_entries'));
    expect(cache, contains('_requests'));
    expect(cache, contains('static String? cachedUrl('));
    expect(cache, contains('static String? cachedPreviewUrl('));
    expect(cache, contains('static Future<String> getSignedUrl('));
    expect(cache, contains('static Future<String> getPreviewSignedUrl('));
    expect(cache, contains('static void evict('));
    expect(loading, contains('TaskPhotoSignedUrlCache.getPreviewSignedUrl(photo)'));
    expect(sections, contains('TaskPhotoSignedUrlCache.cachedPreviewUrl(photo)'));
    expect(sections, contains('if (cachedUrl != null)'));
    expect(sections, contains('gaplessPlayback: true'));
  });

  test('корзина физически отделена от tap-area открытия фото', () {
    final sections = File(
      'lib/screens/task_details/task_details_sections.dart',
    ).readAsStringSync();
    final viewer = File(
      'lib/screens/task_details/task_details_photo_viewer.dart',
    ).readAsStringSync();

    final tileStart = sections.indexOf('Widget buildPhotoTile(');
    final previewStart = sections.indexOf('Widget buildPhotoPreview(');
    expect(tileStart, greaterThanOrEqualTo(0));
    expect(previewStart, greaterThan(tileStart));
    final tile = sections.substring(tileStart, previewStart);

    expect(tile, contains('return Stack('));
    expect(tile, contains('Positioned.fill('));
    expect(tile, contains('child: InkWell('));
    expect(tile, contains('deletePhotoFromTile(photo)'));
    expect(viewer, contains('final stillExists = photos.any('));
    expect(viewer, contains('TaskPhotoSignedUrlCache.evict(photo)'));
  });
}
