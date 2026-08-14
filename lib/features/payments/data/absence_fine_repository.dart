import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../../../data/payment_receipt_repository.dart';

class AbsenceFineItem {
  final String id;
  final String employeeId;
  final String employeeName;
  final String objectName;
  final DateTime absenceDate;
  final double amount;
  final String status;
  final String explanationFileName;
  final String explanationFilePath;
  final String explanationContentType;
  final DateTime? explanationUploadedAt;
  final String actFileName;
  final String actFilePath;
  final String actContentType;
  final DateTime? actUploadedAt;

  const AbsenceFineItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.objectName,
    required this.absenceDate,
    required this.amount,
    required this.status,
    required this.explanationFileName,
    required this.explanationFilePath,
    required this.explanationContentType,
    required this.explanationUploadedAt,
    required this.actFileName,
    required this.actFilePath,
    required this.actContentType,
    required this.actUploadedAt,
  });

  bool get hasExplanation => explanationFilePath.trim().isNotEmpty;
  bool get hasAct => actFilePath.trim().isNotEmpty;
  bool get canConfirm => hasExplanation && hasAct;

  factory AbsenceFineItem.fromMap(Map<String, dynamic> map) {
    return AbsenceFineItem(
      id: map['id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      employeeName: map['employee_name']?.toString().trim() ?? 'Сотрудник',
      objectName: map['object_name']?.toString().trim() ?? '',
      absenceDate:
          DateTime.tryParse(map['absence_date']?.toString() ?? '') ??
          DateTime.now(),
      amount: (map['amount'] is num)
          ? (map['amount'] as num).toDouble()
          : double.tryParse(map['amount']?.toString() ?? '') ?? 10000,
      status: map['status']?.toString() ?? 'pending',
      explanationFileName:
          map['explanation_file_name']?.toString().trim() ?? '',
      explanationFilePath:
          map['explanation_file_path']?.toString().trim() ?? '',
      explanationContentType:
          map['explanation_content_type']?.toString().trim() ?? '',
      explanationUploadedAt: DateTime.tryParse(
        map['explanation_uploaded_at']?.toString() ?? '',
      )?.toLocal(),
      actFileName: map['act_file_name']?.toString().trim() ?? '',
      actFilePath: map['act_file_path']?.toString().trim() ?? '',
      actContentType: map['act_content_type']?.toString().trim() ?? '',
      actUploadedAt: DateTime.tryParse(
        map['act_uploaded_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

class AbsenceFineRepository {
  static final _client = Supabase.instance.client;
  static const explanationBucketName = 'absence-explanations';
  static const actBucketName = 'absence-fine-acts';

  static Future<List<AbsenceFineItem>> fetchPending() async {
    final response = await _client.rpc<dynamic>('get_pending_absence_fines');
    if (response is! List) return const <AbsenceFineItem>[];

    return response
        .whereType<Map>()
        .map((row) => AbsenceFineItem.fromMap(Map<String, dynamic>.from(row)))
        .where((item) => item.id.isNotEmpty && item.employeeId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<PickedPaymentReceiptFile?> pickDocument() async {
    final files = await PaymentReceiptRepository.pickReceiptFiles();
    if (files.isEmpty) return null;
    return files.first;
  }

  static Future<void> uploadExplanation({
    required AbsenceFineItem fine,
    required PickedPaymentReceiptFile file,
  }) async {
    await _uploadDocument(
      fine: fine,
      file: file,
      bucketName: explanationBucketName,
      rpcName: 'attach_absence_fine_explanation',
      errorMessage: 'Не удалось привязать объяснительную',
    );
  }

  static Future<void> uploadAct({
    required AbsenceFineItem fine,
    required PickedPaymentReceiptFile file,
  }) async {
    await _uploadDocument(
      fine: fine,
      file: file,
      bucketName: actBucketName,
      rpcName: 'attach_absence_fine_act',
      errorMessage: 'Не удалось привязать акт о нарушении',
    );
  }

  static Future<void> _uploadDocument({
    required AbsenceFineItem fine,
    required PickedPaymentReceiptFile file,
    required String bucketName,
    required String rpcName,
    required String errorMessage,
  }) async {
    PaymentReceiptRepository.validateFileSize(
      fileName: file.originalName,
      sizeBytes: file.sizeBytes,
    );

    final path = '${fine.employeeId}/${fine.id}/${file.storageFileName}';
    await _client.storage.from(bucketName).uploadBinary(
      path,
      file.bytes,
      fileOptions: FileOptions(
        contentType: file.contentType,
        upsert: false,
      ),
    );

    try {
      final attached = await _client.rpc<dynamic>(
        rpcName,
        params: <String, dynamic>{
          'p_fine_id': fine.id,
          'p_file_name': file.originalName,
          'p_file_path': path,
          'p_content_type': file.contentType,
        },
      );
      if (attached != true) throw StateError(errorMessage);
    } catch (_) {
      try {
        await _client.storage.from(bucketName).remove(<String>[path]);
      } catch (_) {
        // Не маскируем основную ошибку служебной очисткой.
      }
      rethrow;
    }
  }

  static Future<String> confirm(AbsenceFineItem fine) async {
    final response = await _client.rpc<dynamic>(
      'confirm_absence_fine',
      params: <String, dynamic>{'p_fine_id': fine.id},
    );
    final paymentId = response?.toString() ?? '';
    if (paymentId.isEmpty) throw StateError('Выплата-штраф не создана');

    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.payments},
      context: <String, dynamic>{
        'table': 'payments',
        'employee_id': fine.employeeId,
        'payment_type': 'fine',
      },
    );
    return paymentId;
  }
}
