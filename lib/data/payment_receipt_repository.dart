import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import 'image_compression_service.dart';

class PaymentReceipt {
  final String id;
  final String paymentId;
  final String employeeId;
  final String fileName;
  final String filePath;
  final String contentType;
  final DateTime createdAt;

  const PaymentReceipt({
    required this.id,
    required this.paymentId,
    required this.employeeId,
    required this.fileName,
    required this.filePath,
    required this.contentType,
    required this.createdAt,
  });

  factory PaymentReceipt.fromMap(Map<String, dynamic> map) {
    return PaymentReceipt(
      id: map['id']?.toString() ?? '',
      paymentId: map['payment_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? '',
      filePath: map['file_path']?.toString() ?? '',
      contentType: map['content_type']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class PickedPaymentReceiptFile {
  final String originalName;
  final String storageFileName;
  final String extension;
  final String contentType;
  final Uint8List bytes;

  const PickedPaymentReceiptFile({
    required this.originalName,
    required this.storageFileName,
    required this.extension,
    required this.contentType,
    required this.bytes,
  });

  int get sizeBytes => bytes.length;
}

class PaymentReceiptRepository {
  static final _client = Supabase.instance.client;

  static const bucketName = 'payment-receipts';
  static const int maxFileSizeBytes = 20 * 1024 * 1024;

  /// Совпадает с форматами, разрешёнными в Supabase Storage.
  static const List<String> allowedExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static String extensionFromFileName(String name) {
    final cleanName = name.trim();
    final dotIndex = cleanName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == cleanName.length - 1) return '';

    return cleanName.substring(dotIndex + 1).toLowerCase();
  }

  static bool isAllowedExtension(String extension) {
    return allowedExtensions.contains(extension.trim().toLowerCase());
  }

  static String contentTypeFromExtension(String extension) {
    final clean = extension.trim().toLowerCase();

    if (clean == 'pdf') return 'application/pdf';
    if (clean == 'jpg' || clean == 'jpeg') return 'image/jpeg';
    if (clean == 'png') return 'image/png';
    if (clean == 'webp') return 'image/webp';

    return 'application/octet-stream';
  }

  static String safePart(String value) {
    final clean = value.trim();

    if (clean.isEmpty) return 'file';

    return clean
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static String safeStorageFileName({
    required String originalName,
    required int index,
    required String extension,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanExtension = extension.trim().toLowerCase();

    final nameWithoutExtension = originalName.contains('.')
        ? originalName.substring(0, originalName.lastIndexOf('.'))
        : originalName;

    final cleanName = safePart(nameWithoutExtension);
    final shortName = cleanName.length > 48
        ? cleanName.substring(0, 48)
        : cleanName;

    if (cleanExtension.isEmpty) {
      return '${timestamp}_${index}_$shortName';
    }

    return '${timestamp}_${index}_$shortName.$cleanExtension';
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';

    final kb = bytes / 1024;

    if (kb < 1024) return '${kb.toStringAsFixed(1)} КБ';

    final mb = kb / 1024;

    return '${mb.toStringAsFixed(1)} МБ';
  }

  static void validateFileSize({
    required String fileName,
    required int sizeBytes,
  }) {
    if (sizeBytes <= maxFileSizeBytes) return;

    throw Exception(
      'Файл "$fileName" слишком большой: ${formatFileSize(sizeBytes)}. Максимум 20 МБ.',
    );
  }

  static Future<List<PickedPaymentReceiptFile>> pickReceiptFiles() async {
    if (kIsWeb) {
      return pickReceiptFilesWeb();
    }

    return pickReceiptFilesNative();
  }

  static Future<List<PickedPaymentReceiptFile>> pickReceiptFilesNative() async {
    const typeGroup = XTypeGroup(label: 'Чеки', extensions: allowedExtensions);

    final files = await openFiles(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

    if (files.isEmpty) {
      return <PickedPaymentReceiptFile>[];
    }

    final pickedFiles = <PickedPaymentReceiptFile>[];

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final originalName = file.name.trim().isEmpty
          ? 'receipt_${i + 1}'
          : file.name.trim();

      final extension = extensionFromFileName(originalName);

      if (!isAllowedExtension(extension)) {
        throw Exception('Неподдерживаемый формат файла: $originalName');
      }

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Не удалось прочитать файл: $originalName');
      }

      validateFileSize(fileName: originalName, sizeBytes: bytes.length);

      final storageFileName = safeStorageFileName(
        originalName: originalName,
        index: i + 1,
        extension: extension,
      );

      pickedFiles.add(
        PickedPaymentReceiptFile(
          originalName: originalName,
          storageFileName: storageFileName,
          extension: extension,
          contentType: contentTypeFromExtension(extension),
          bytes: Uint8List.fromList(bytes),
        ),
      );
    }

    return pickedFiles;
  }

  static Future<List<PickedPaymentReceiptFile>> pickReceiptFilesWeb() async {
    final completer = Completer<List<PickedPaymentReceiptFile>>();

    final uploadInput = html.FileUploadInputElement()
      ..accept = allowedExtensions.map((extension) => '.$extension').join(',')
      ..multiple = true;

    uploadInput.onChange.listen((_) async {
      try {
        final files = uploadInput.files;

        if (files == null || files.isEmpty) {
          completer.complete(<PickedPaymentReceiptFile>[]);
          return;
        }

        final pickedFiles = <PickedPaymentReceiptFile>[];

        for (var i = 0; i < files.length; i++) {
          final file = files[i];
          final originalName = file.name.trim().isEmpty
              ? 'receipt_${i + 1}'
              : file.name.trim();

          final originalExtension = extensionFromFileName(originalName);

          if (!isAllowedExtension(originalExtension)) {
            throw Exception('Неподдерживаемый формат файла: $originalName');
          }

          final originalBytes = await readWebFileAsBytes(file);

          if (originalBytes.isEmpty) {
            throw Exception('Не удалось прочитать файл: $originalName');
          }

          var finalBytes = originalBytes;
          var finalExtension = originalExtension;
          var finalContentType = file.type.trim().isEmpty
              ? contentTypeFromExtension(originalExtension)
              : file.type.trim();

          if (ImageCompressionService.isSupportedImageExtension(
            originalExtension,
          )) {
            final compressed =
                await ImageCompressionService.compressHtmlImageFile(
                  file: file,
                  originalBytes: originalBytes,
                  originalName: originalName,
                  maxDimension: 1800,
                  jpegQuality: 0.82,
                );

            finalBytes = compressed.bytes;
            finalExtension = compressed.extension.isEmpty
                ? originalExtension
                : compressed.extension;
            finalContentType = compressed.contentType;
          }

          validateFileSize(
            fileName: originalName,
            sizeBytes: finalBytes.length,
          );

          final storageFileName = safeStorageFileName(
            originalName: originalName,
            index: i + 1,
            extension: finalExtension,
          );

          pickedFiles.add(
            PickedPaymentReceiptFile(
              originalName: originalName,
              storageFileName: storageFileName,
              extension: finalExtension,
              contentType: finalContentType,
              bytes: finalBytes,
            ),
          );
        }

        completer.complete(pickedFiles);
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      }
    });

    uploadInput.click();

    return completer.future;
  }

  static Future<Uint8List> readWebFileAsBytes(html.File file) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();

    reader.onLoad.listen((_) {
      final result = reader.result;

      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
        return;
      }

      if (result is Uint8List) {
        completer.complete(result);
        return;
      }

      completer.completeError('Не удалось прочитать файл');
    });

    reader.onError.listen((_) {
      completer.completeError('Ошибка чтения файла');
    });

    reader.readAsArrayBuffer(file);

    return completer.future;
  }

  static Future<List<PaymentReceipt>> uploadReceiptFiles({
    required String paymentId,
    required String employeeId,
    required List<PickedPaymentReceiptFile> files,
  }) async {
    final cleanPaymentId = paymentId.trim();
    final cleanEmployeeId = employeeId.trim();

    if (cleanPaymentId.isEmpty) {
      throw Exception('Не найден ID выплаты');
    }

    if (cleanEmployeeId.isEmpty) {
      throw Exception('Не найден ID сотрудника');
    }

    if (files.isEmpty) return <PaymentReceipt>[];

    final uploadedReceipts = <PaymentReceipt>[];

    for (final file in files) {
      validateFileSize(fileName: file.originalName, sizeBytes: file.sizeBytes);

      final path = '$cleanEmployeeId/$cleanPaymentId/${file.storageFileName}';

      await _client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            file.bytes,
            fileOptions: FileOptions(
              contentType: file.contentType,
              upsert: false,
            ),
          );

      final row = await _client
          .from('payment_receipts')
          .insert({
            'payment_id': cleanPaymentId,
            'employee_id': cleanEmployeeId,
            'file_name': file.originalName.trim().isEmpty
                ? file.storageFileName
                : file.originalName.trim(),
            'file_path': path,
            'content_type': file.contentType,
          })
          .select()
          .single();

      uploadedReceipts.add(PaymentReceipt.fromMap(row));
    }

    return uploadedReceipts;
  }

  static Future<Map<String, List<PaymentReceipt>>> fetchReceiptsForPaymentIds(
    List<String> paymentIds,
  ) async {
    final ids = paymentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) return <String, List<PaymentReceipt>>{};

    final result = <String, List<PaymentReceipt>>{};
    const chunkSize = 80;

    for (var start = 0; start < ids.length; start += chunkSize) {
      final end = math.min(start + chunkSize, ids.length);
      final chunk = ids.sublist(start, end);

      final rows = await _client
          .from('payment_receipts')
          .select()
          .inFilter('payment_id', chunk)
          .order('created_at', ascending: false);

      for (final row in rows) {
        final receipt = PaymentReceipt.fromMap(row);

        if (receipt.paymentId.isEmpty) continue;

        result.putIfAbsent(receipt.paymentId, () => <PaymentReceipt>[]);
        result[receipt.paymentId]!.add(receipt);
      }
    }

    return result;
  }

  static Future<List<PaymentReceipt>> fetchReceiptsForPayment(
    String paymentId,
  ) async {
    final map = await fetchReceiptsForPaymentIds([paymentId]);

    return List<PaymentReceipt>.from(map[paymentId] ?? <PaymentReceipt>[]);
  }

  static Future<void> openReceipt(PaymentReceipt receipt) async {
    if (receipt.filePath.trim().isEmpty) {
      throw Exception('У чека нет пути к файлу');
    }

    final url = await _client.storage
        .from(bucketName)
        .createSignedUrl(receipt.filePath, 60 * 10);

    html.window.open(url, '_blank');
  }

  static Future<void> deleteReceiptsForPayment(String paymentId) async {
    final receipts = await fetchReceiptsForPayment(paymentId);

    final paths = receipts
        .map((receipt) => receipt.filePath.trim())
        .where((path) => path.isNotEmpty)
        .toList();

    if (paths.isNotEmpty) {
      await _client.storage.from(bucketName).remove(paths);
    }

    await _client.from('payment_receipts').delete().eq('payment_id', paymentId);
  }
}
