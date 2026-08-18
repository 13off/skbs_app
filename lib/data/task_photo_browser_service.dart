import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

import 'image_compression_service.dart';
import 'task_photo_models.dart';
import 'task_photo_native_picker_service.dart';

class TaskPhotoBrowserService {
  static const acceptedFileTypes = 'image/*,.heic,.heif';
  static const Duration fileReadTimeout = Duration(seconds: 25);
  static const int prepareConcurrency = 2;

  const TaskPhotoBrowserService._();

  static String extensionFromFileName(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return '';

    final extension = name.substring(dotIndex + 1).toLowerCase();
    const allowedExtensions = {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
    };
    return allowedExtensions.contains(extension) ? extension : '';
  }

  static String extensionFromContentType(String contentType) {
    final clean = contentType.trim().toLowerCase().split(';').first;
    return switch (clean) {
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' || 'image/heic-sequence' => 'heic',
      'image/heif' || 'image/heif-sequence' => 'heif',
      _ => '',
    };
  }

  static String extensionForFile(html.File file) {
    final fromName = extensionFromFileName(file.name);
    if (fromName.isNotEmpty) return fromName;
    return extensionFromContentType(file.type);
  }

  static bool requiresJpegNormalization({
    required String extension,
    required String contentType,
  }) {
    final cleanExtension = extension.trim().toLowerCase();
    final cleanContentType = contentType.trim().toLowerCase();
    return cleanExtension == 'heic' ||
        cleanExtension == 'heif' ||
        cleanContentType.startsWith('image/heic') ||
        cleanContentType.startsWith('image/heif');
  }

  static Uint8List bytesFromReaderResult(Object? result) {
    if (result is Uint8List) return result;
    if (result is ByteBuffer) return Uint8List.view(result);
    throw Exception('Не удалось прочитать фото');
  }

  static Future<Uint8List> readFileBytes(html.File file) async {
    final reader = html.FileReader();
    final loaded = reader.onLoad.first.then<Uint8List>((_) {
      return bytesFromReaderResult(reader.result);
    });
    final failed = reader.onError.first.then<Uint8List>((_) {
      throw Exception('Не удалось прочитать фото ${file.name}');
    });

    reader.readAsArrayBuffer(file);

    return Future.any<Uint8List>(<Future<Uint8List>>[loaded, failed]).timeout(
      fileReadTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Фото ${file.name} слишком долго обрабатывается. Попробуйте ещё раз.',
        );
      },
    );
  }

  static Future<TaskPhotoFile> _preparePhotoFile(html.File file) async {
    final extension = extensionForFile(file);
    if (extension.isEmpty) {
      throw Exception(
        'Не удалось определить формат фотографии ${file.name}. '
        'Выберите изображение из медиатеки ещё раз.',
      );
    }

    final originalBytes = await readFileBytes(file);
    final forceJpeg = requiresJpegNormalization(
      extension: extension,
      contentType: file.type,
    );
    final compressedPhoto = await ImageCompressionService.compressHtmlImageFile(
      file: file,
      originalBytes: originalBytes,
      originalName: file.name,
      maxDimension: 1440,
      jpegQuality: 0.78,
      forceJpeg: forceJpeg,
    );

    if (forceJpeg && compressedPhoto.extension != 'jpg') {
      throw Exception(
        'Не удалось преобразовать фото iPhone ${file.name} в JPEG. '
        'Попробуйте выбрать это фото ещё раз.',
      );
    }

    return TaskPhotoFile(
      originalName: file.name,
      contentType: compressedPhoto.contentType,
      extension: compressedPhoto.extension.isEmpty
          ? extension
          : compressedPhoto.extension,
      bytes: compressedPhoto.bytes,
    );
  }

  static Future<List<TaskPhotoFile>> pickPhotoFiles({
    void Function(int completed, int total)? onPrepareProgress,
  }) async {
    if (!kIsWeb) {
      final photos = await TaskPhotoNativePickerService.pickPhotoFiles();
      if (photos.isNotEmpty) {
        onPrepareProgress?.call(photos.length, photos.length);
      }
      return photos;
    }

    final input = html.FileUploadInputElement()
      ..multiple = true
      ..accept = acceptedFileTypes;

    input.click();
    await input.onChange.first;

    final files = input.files;
    if (files == null || files.isEmpty) return <TaskPhotoFile>[];

    final selectedFiles = files.toList(growable: false);
    final photos = <TaskPhotoFile>[];
    var completed = 0;
    onPrepareProgress?.call(0, selectedFiles.length);

    for (var start = 0; start < selectedFiles.length; start += prepareConcurrency) {
      final end = (start + prepareConcurrency) < selectedFiles.length
          ? start + prepareConcurrency
          : selectedFiles.length;
      final batch = await Future.wait(
        selectedFiles.sublist(start, end).map(_preparePhotoFile),
      );
      photos.addAll(batch);
      completed += batch.length;
      onPrepareProgress?.call(completed, selectedFiles.length);
    }

    return photos;
  }

  static void openUrl(String url) {
    if (kIsWeb) {
      html.window.open(url, '_blank');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }
}
