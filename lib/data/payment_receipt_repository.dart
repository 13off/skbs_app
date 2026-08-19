import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const Duration _fileReadTimeout = Duration(seconds: 45);
  static const Duration _uploadTimeout = Duration(seconds: 45);
  static const Duration _authRefreshTimeout = Duration(seconds: 15);
  static const int _maxUploadAttempts = 3;

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

  /// Чистит имя для локального скачивания. Здесь кириллица допустима.
  static String safePart(String value) {
    final clean = value.trim();

    if (clean.isEmpty) return 'file';

    return clean
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Storage key намеренно не содержит исходное имя файла.
  /// Supabase Storage принимает ограниченный набор символов в object key,
  /// поэтому кириллица и другие пользовательские символы остаются только в
  /// payment_receipts.file_name и никогда не попадают в путь объекта.
  static String safeStorageFileName({
    required String originalName,
    required int index,
    required String extension,
  }) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final nonce = math.Random().nextInt(0xFFFFFF).toRadixString(16);
    final cleanExtension = extension.trim().toLowerCase();

    var hash = 0;
    for (final codeUnit in originalName.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    final originalHash = hash.toRadixString(16);
    final baseName = '${timestamp}_${index}_${nonce}_$originalHash';

    if (cleanExtension.isEmpty) return baseName;
    return '$baseName.$cleanExtension';
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

  /// Используем один и тот же поддерживаемый file_selector на Web/PWA и native.
  static Future<List<PickedPaymentReceiptFile>> pickReceiptFiles() {
    return pickReceiptFilesNative();
  }

  static Future<List<PickedPaymentReceiptFile>> pickReceiptFilesNative() async {
    const typeGroup = XTypeGroup(
      label: 'Чеки',
      extensions: allowedExtensions,
      uniformTypeIdentifiers: <String>[
        'public.jpeg',
        'public.png',
        'org.webmproject.webp',
        'com.adobe.pdf',
      ],
    );

    final files = await openFiles(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (files.isEmpty) return <PickedPaymentReceiptFile>[];

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

      final bytes = await file.readAsBytes().timeout(
        _fileReadTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Не удалось прочитать файл вовремя: $originalName',
          );
        },
      );

      if (bytes.isEmpty) {
        throw Exception('Не удалось прочитать файл: $originalName');
      }

      validateFileSize(fileName: originalName, sizeBytes: bytes.length);

      pickedFiles.add(
        PickedPaymentReceiptFile(
          originalName: originalName,
          storageFileName: safeStorageFileName(
            originalName: originalName,
            index: i + 1,
            extension: extension,
          ),
          extension: extension,
          contentType: contentTypeFromExtension(extension),
          bytes: Uint8List.fromList(bytes),
        ),
      );
    }

    return pickedFiles;
  }

  /// Оставлено для обратной совместимости с тестами/старыми вызовами.
  static Future<List<PickedPaymentReceiptFile>> pickReceiptFilesWeb() {
    return pickReceiptFilesNative();
  }

  static Future<void> _refreshSessionBestEffort() async {
    if (_client.auth.currentSession == null) return;

    try {
      await _client.auth.refreshSession().timeout(_authRefreshTimeout);
    } catch (_) {
      // Основная загрузка ниже всё равно вернёт понятную ошибку пользователю.
    }
  }

  static Future<void> _removePathBestEffort(String path) async {
    try {
      await _client.storage
          .from(bucketName)
          .remove(<String>[path])
          .timeout(_authRefreshTimeout);
    } catch (_) {
      // Очистка не должна скрывать исходную ошибку загрузки.
    }
  }

  static Future<void> _uploadReceiptWithRetry({
    required PickedPaymentReceiptFile file,
    required String path,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxUploadAttempts; attempt++) {
      if (attempt > 1) {
        await _refreshSessionBestEffort();
        await _removePathBestEffort(path);
        await Future<void>.delayed(Duration(milliseconds: 450 * attempt));
      }

      try {
        await _client.storage
            .from(bucketName)
            .uploadBinary(
              path,
              file.bytes,
              fileOptions: FileOptions(
                contentType: file.contentType,
                upsert: false,
              ),
            )
            .timeout(
              _uploadTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Истекло время загрузки файла ${file.originalName}',
                );
              },
            );
        return;
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(
      'Не удалось загрузить чек "${file.originalName}" после $_maxUploadAttempts попыток. Проверьте интернет и повторите. Причина: $lastError',
    );
  }

  static Future<List<PaymentReceipt>> uploadReceiptFiles({
    required String paymentId,
    required String employeeId,
    required List<PickedPaymentReceiptFile> files,
  }) async {
    final cleanPaymentId = paymentId.trim();
    final cleanEmployeeId = employeeId.trim();

    if (cleanPaymentId.isEmpty) throw Exception('Не найден ID выплаты');
    if (cleanEmployeeId.isEmpty) throw Exception('Не найден ID сотрудника');
    if (files.isEmpty) return <PaymentReceipt>[];

    final uploadItems = files.map((file) {
      validateFileSize(fileName: file.originalName, sizeBytes: file.sizeBytes);
      final path = '$cleanEmployeeId/$cleanPaymentId/${file.storageFileName}';
      return (file: file, path: path);
    }).toList();
    final uploadedPaths = <String>[];

    try {
      // Последовательная загрузка предсказуемее на мобильных сетях.
      for (final item in uploadItems) {
        await _uploadReceiptWithRetry(file: item.file, path: item.path);
        uploadedPaths.add(item.path);
      }

      final rows = await _client
          .from('payment_receipts')
          .insert(
            uploadItems
                .map(
                  (item) => <String, dynamic>{
                    'payment_id': cleanPaymentId,
                    'employee_id': cleanEmployeeId,
                    'file_name': item.file.originalName.trim().isEmpty
                        ? item.file.storageFileName
                        : item.file.originalName.trim(),
                    'file_path': item.path,
                    'content_type': item.file.contentType,
                  },
                )
                .toList(),
          )
          .select();

      return rows.map<PaymentReceipt>(PaymentReceipt.fromMap).toList();
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _client.storage.from(bucketName).remove(uploadedPaths);
        } catch (_) {
          // Служебная очистка удалит оставшиеся файлы.
        }
      }
      rethrow;
    }
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

  static String _downloadExtension(PaymentReceipt receipt) {
    final fromName = extensionFromFileName(receipt.fileName);
    if (isAllowedExtension(fromName)) {
      return fromName == 'jpeg' ? 'jpg' : fromName;
    }

    final fromPath = extensionFromFileName(receipt.filePath);
    if (isAllowedExtension(fromPath)) {
      return fromPath == 'jpeg' ? 'jpg' : fromPath;
    }

    switch (receipt.contentType.trim().toLowerCase()) {
      case 'application/pdf':
        return 'pdf';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }

  static Future<String> _downloadBaseName(PaymentReceipt receipt) async {
    final parts = <String>['Чек'];

    try {
      final payment = await _client
          .from('payments')
          .select('employee_id,payment_date,amount')
          .eq('id', receipt.paymentId)
          .maybeSingle();

      final employeeId = payment?['employee_id']?.toString().trim() ?? '';
      if (employeeId.isNotEmpty) {
        final employee = await _client
            .from('employees')
            .select('fio')
            .eq('id', employeeId)
            .maybeSingle();
        final fio = employee?['fio']?.toString().trim() ?? '';
        if (fio.isNotEmpty) parts.add(fio);
      }

      final paymentDate = DateTime.tryParse(
        payment?['payment_date']?.toString() ?? '',
      );
      if (paymentDate != null) {
        parts.add(
          '${paymentDate.day.toString().padLeft(2, '0')}.${paymentDate.month.toString().padLeft(2, '0')}.${paymentDate.year}',
        );
      }

      final amount = payment?['amount'];
      if (amount is num) parts.add(amount.round().toString());
    } catch (_) {
      // Название чека не должно мешать самому скачиванию файла.
    }

    if (receipt.id.trim().isNotEmpty) {
      final id = receipt.id.trim();
      parts.add(id.length > 8 ? id.substring(0, 8) : id);
    }

    return parts.map(safePart).join('_');
  }

  static Future<void> downloadReceipt(PaymentReceipt receipt) async {
    if (receipt.filePath.trim().isEmpty) {
      throw Exception('У чека нет пути к файлу');
    }

    final bytes = await _client.storage
        .from(bucketName)
        .download(receipt.filePath);
    if (bytes.isEmpty) throw Exception('Не удалось скачать чек');

    final extension = _downloadExtension(receipt);
    final contentType = receipt.contentType.trim().isEmpty
        ? contentTypeFromExtension(extension)
        : receipt.contentType.trim();
    final baseName = await _downloadBaseName(receipt);

    await FileSaver.instance.saveFile(
      name: baseName,
      bytes: bytes,
      fileExtension: extension,
      mimeType: MimeType.custom,
      customMimeType: contentType,
    );
  }

  static Future<void> openReceipt(PaymentReceipt receipt) {
    return downloadReceipt(receipt);
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
