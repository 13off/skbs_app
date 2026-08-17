import 'dart:async';
import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

class CompressedImageFile {
  final String originalName;
  final String contentType;
  final String extension;
  final Uint8List bytes;
  final int originalSize;
  final bool wasCompressed;

  const CompressedImageFile({
    required this.originalName,
    required this.contentType,
    required this.extension,
    required this.bytes,
    required this.originalSize,
    required this.wasCompressed,
  });
}

class ImageCompressionService {
  static const int defaultMaxDimension = 1600;
  static const double defaultJpegQuality = 0.82;
  static const int defaultMinInputBytes = 260 * 1024;
  static const int defaultMinSavingPercent = 8;
  static const Duration imageDecodeTimeout = Duration(seconds: 25);
  static const Duration blobReadTimeout = Duration(seconds: 25);

  static bool isSupportedImageExtension(String extension) {
    final clean = extension.trim().toLowerCase();

    return clean == 'jpg' ||
        clean == 'jpeg' ||
        clean == 'png' ||
        clean == 'webp' ||
        clean == 'heic' ||
        clean == 'heif';
  }

  static String extensionFromFileName(String name) {
    final cleanName = name.trim();
    final dotIndex = cleanName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == cleanName.length - 1) {
      return '';
    }

    return cleanName.substring(dotIndex + 1).toLowerCase();
  }

  static Future<CompressedImageFile> compressHtmlImageFile({
    required html.File file,
    required Uint8List originalBytes,
    required String originalName,
    int maxDimension = defaultMaxDimension,
    double jpegQuality = defaultJpegQuality,
    int minInputBytes = defaultMinInputBytes,
    int minSavingPercent = defaultMinSavingPercent,
    bool forceJpeg = false,
  }) async {
    final originalExtension = extensionFromFileName(originalName);
    final fallbackContentType = file.type.isEmpty
        ? _contentTypeFromExtension(originalExtension)
        : file.type;

    final fallback = CompressedImageFile(
      originalName: originalName,
      contentType: fallbackContentType,
      extension: originalExtension,
      bytes: originalBytes,
      originalSize: originalBytes.length,
      wasCompressed: false,
    );

    if (!isSupportedImageExtension(originalExtension) && !forceJpeg) {
      return fallback;
    }

    if (!forceJpeg &&
        originalBytes.length < minInputBytes &&
        originalExtension != 'png') {
      return fallback;
    }

    final objectUrl = html.Url.createObjectUrlFromBlob(file);

    try {
      final image = await _loadImage(objectUrl).timeout(imageDecodeTimeout);

      final int sourceWidth = _safeDimension(image.naturalWidth);
      final int sourceHeight = _safeDimension(image.naturalHeight);

      if (sourceWidth <= 0 || sourceHeight <= 0) {
        if (forceJpeg) {
          throw Exception('Не удалось определить размер изображения');
        }
        return fallback;
      }

      final int longestSide = sourceWidth >= sourceHeight
          ? sourceWidth
          : sourceHeight;

      final double scale = longestSide > maxDimension
          ? maxDimension / longestSide
          : 1.0;

      final int calculatedWidth = (sourceWidth * scale).round();
      final int calculatedHeight = (sourceHeight * scale).round();

      final int targetWidth = calculatedWidth < 1 ? 1 : calculatedWidth;
      final int targetHeight = calculatedHeight < 1 ? 1 : calculatedHeight;

      final canvas = html.CanvasElement(
        width: targetWidth,
        height: targetHeight,
      );

      final context = canvas.context2D;

      context.fillStyle = '#FFFFFF';
      context.fillRect(0, 0, targetWidth, targetHeight);
      context.drawImageScaled(image, 0, 0, targetWidth, targetHeight);

      // toBlob выполняет кодирование асинхронно и не создаёт огромную
      // промежуточную base64-строку, поэтому выбор фото не блокирует UI.
      final blob = await canvas.toBlob('image/jpeg', jpegQuality);
      final compressedBytes = await _bytesFromBlob(
        blob,
      ).timeout(blobReadTimeout);

      if (compressedBytes.isEmpty) {
        if (forceJpeg) {
          throw Exception('JPEG после преобразования пуст');
        }
        return fallback;
      }

      if (forceJpeg) {
        return CompressedImageFile(
          originalName: originalName,
          contentType: 'image/jpeg',
          extension: 'jpg',
          bytes: compressedBytes,
          originalSize: originalBytes.length,
          wasCompressed: true,
        );
      }

      if (compressedBytes.length >= originalBytes.length) {
        return fallback;
      }

      final savedPercent =
          ((originalBytes.length - compressedBytes.length) /
              originalBytes.length) *
          100;

      if (savedPercent < minSavingPercent) {
        return fallback;
      }

      return CompressedImageFile(
        originalName: originalName,
        contentType: 'image/jpeg',
        extension: 'jpg',
        bytes: compressedBytes,
        originalSize: originalBytes.length,
        wasCompressed: true,
      );
    } on TimeoutException {
      if (forceJpeg) {
        throw Exception(
          'Фото iPhone слишком долго преобразуется в JPEG. Попробуйте ещё раз.',
        );
      }
      return fallback;
    } catch (_) {
      if (forceJpeg) {
        throw Exception(
          'Не удалось преобразовать фото iPhone в JPEG. Попробуйте выбрать фото ещё раз.',
        );
      }
      return fallback;
    } finally {
      html.Url.revokeObjectUrl(objectUrl);
    }
  }

  static int _safeDimension(int? value) {
    if (value == null) {
      return 0;
    }

    return value;
  }

  static Future<html.ImageElement> _loadImage(String objectUrl) {
    final completer = Completer<html.ImageElement>();
    final image = html.ImageElement();

    late final StreamSubscription<html.Event> loadSubscription;
    late final StreamSubscription<html.Event> errorSubscription;

    void finishWithImage() {
      if (!completer.isCompleted) {
        completer.complete(image);
      }

      loadSubscription.cancel();
      errorSubscription.cancel();
    }

    void finishWithError(Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }

      loadSubscription.cancel();
      errorSubscription.cancel();
    }

    loadSubscription = image.onLoad.listen((_) {
      finishWithImage();
    });

    errorSubscription = image.onError.listen((_) {
      finishWithError(Exception('Не удалось обработать изображение'));
    });

    image.src = objectUrl;

    return completer.future;
  }

  static Future<Uint8List> _bytesFromBlob(html.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();

    late final StreamSubscription<html.ProgressEvent> loadSubscription;
    late final StreamSubscription<html.ProgressEvent> errorSubscription;

    void finish(Uint8List bytes) {
      if (!completer.isCompleted) {
        completer.complete(bytes);
      }
      loadSubscription.cancel();
      errorSubscription.cancel();
    }

    void fail(Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
      loadSubscription.cancel();
      errorSubscription.cancel();
    }

    loadSubscription = reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        finish(Uint8List.view(result));
      } else if (result is Uint8List) {
        finish(result);
      } else {
        fail(Exception('Не удалось прочитать сжатое изображение'));
      }
    });

    errorSubscription = reader.onError.listen((_) {
      fail(Exception('Не удалось прочитать сжатое изображение'));
    });

    reader.readAsArrayBuffer(blob);
    return completer.future;
  }

  static String _contentTypeFromExtension(String extension) {
    final clean = extension.trim().toLowerCase();

    if (clean == 'jpg' || clean == 'jpeg') return 'image/jpeg';
    if (clean == 'png') return 'image/png';
    if (clean == 'webp') return 'image/webp';
    if (clean == 'heic') return 'image/heic';
    if (clean == 'heif') return 'image/heif';

    return 'application/octet-stream';
  }
}
