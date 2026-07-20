import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

import 'image_compression_service.dart';
import 'task_photo_models.dart';

class TaskPhotoBrowserService {
  static const acceptedFileTypes =
      'image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp';

  const TaskPhotoBrowserService._();

  static String extensionFromFileName(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return '';

    final extension = name.substring(dotIndex + 1).toLowerCase();
    const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
    return allowedExtensions.contains(extension) ? extension : '';
  }

  static Uint8List bytesFromReaderResult(Object? result) {
    if (result is Uint8List) return result;
    if (result is ByteBuffer) return Uint8List.view(result);
    throw Exception('Не удалось прочитать фото');
  }

  static Future<List<TaskPhotoFile>> pickPhotoFiles() async {
    final input = html.FileUploadInputElement()
      ..multiple = true
      ..accept = acceptedFileTypes;

    input.click();
    await input.onChange.first;

    final files = input.files;
    if (files == null || files.isEmpty) return <TaskPhotoFile>[];

    final photos = <TaskPhotoFile>[];
    for (final file in files) {
      final extension = extensionFromFileName(file.name);
      if (extension.isEmpty) {
        throw Exception(
          'Можно загрузить только JPG, PNG или WEBP: ${file.name}',
        );
      }

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final originalBytes = bytesFromReaderResult(reader.result);
      final compressedPhoto =
          await ImageCompressionService.compressHtmlImageFile(
            file: file,
            originalBytes: originalBytes,
            originalName: file.name,
            maxDimension: 1600,
            jpegQuality: 0.82,
          );

      photos.add(
        TaskPhotoFile(
          originalName: file.name,
          contentType: compressedPhoto.contentType,
          extension: compressedPhoto.extension.isEmpty
              ? extension
              : compressedPhoto.extension,
          bytes: compressedPhoto.bytes,
        ),
      );
    }

    return photos;
  }

  static void openUrl(String url) {
    html.window.open(url, '_blank');
  }
}
