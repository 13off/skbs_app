import 'dart:async';
import 'dart:convert';
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

  static bool isSupportedImageExtension(String extension) {
    final clean = extension.trim().toLowerCase();

    return clean == 'jpg' ||
        clean == 'jpeg' ||
        clean == 'png' ||
        clean == 'webp';
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

    if (!isSupportedImageExtension(originalExtension)) {
      return fallback;
    }

    if (originalBytes.length < minInputBytes && originalExtension != 'png') {
      return fallback;
    }

    final objectUrl = html.Url.createObjectUrlFromBlob(file);

    try {
      final image = await _loadImage(objectUrl);

      final int sourceWidth = _safeDimension(image.naturalWidth);
      final int sourceHeight = _safeDimension(image.naturalHeight);

      if (sourceWidth <= 0 || sourceHeight <= 0) {
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

      final dataUrl = canvas.toDataUrl('image/jpeg', jpegQuality);
      final compressedBytes = _bytesFromDataUrl(dataUrl);

      if (compressedBytes.isEmpty ||
          compressedBytes.length >= originalBytes.length) {
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
    } catch (_) {
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

  static Uint8List _bytesFromDataUrl(String dataUrl) {
    final commaIndex = dataUrl.indexOf(',');

    if (commaIndex == -1 || commaIndex == dataUrl.length - 1) {
      return Uint8List(0);
    }

    final base64Part = dataUrl.substring(commaIndex + 1);

    return Uint8List.fromList(base64Decode(base64Part));
  }

  static String _contentTypeFromExtension(String extension) {
    final clean = extension.trim().toLowerCase();

    if (clean == 'jpg' || clean == 'jpeg') return 'image/jpeg';
    if (clean == 'png') return 'image/png';
    if (clean == 'webp') return 'image/webp';

    return 'application/octet-stream';
  }
}
