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
  final String violationActId;
  final String violationActNumber;
  final String violationActStatus;
  final String violationTitle;
  final String violationDescription;

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
    required this.violationActId,
    required this.violationActNumber,
    required this.violationActStatus,
    required this.violationTitle,
    required this.violationDescription,
  });

  bool get hasExplanation => explanationFilePath.trim().isNotEmpty;
  bool get hasViolationAct => violationActId.trim().isNotEmpty;

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
      violationActId: map['violation_act_id']?.toString().trim() ?? '',
      violationActNumber:
          map['violation_act_number']?.toString().trim() ?? '',
      violationActStatus:
          map['violation_act_status']?.toString().trim() ?? 'pending',
      violationTitle:
          map['violation_title']?.toString().trim() ?? 'Невыход на смену',
      violationDescription:
          map['violation_description']?.toString().trim() ?? '',
    );
  }
}

class AbsenceFineRepository {
  static final _client = Supabase.instance.client;
  static const bucketName = 'absence-explanations';

  static Future<List<AbsenceFineItem>> fetchPending() async {
    final response = await _client.rpc<dynamic>('get_pending_absence_fines_v2');
    if (response is! List) return const <AbsenceFineItem>[];

    return response
        .whereType<Map>()
        .map((row) => AbsenceFineItem.fromMap(Map<String, dynamic>.from(row)))
        .where((item) => item.id.isNotEmpty && item.employeeId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<PickedPaymentReceiptFile?> pickExplanation() async {
    final files = await PaymentReceiptRepository.pickReceiptFiles();
    if (files.isEmpty) return null;
    return files.first;
  }

  static Future<void> uploadExplanation({
    required AbsenceFineItem fine,
    required PickedPaymentReceiptFile file,
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
        'attach_absence_fine_explanation',
        params: <String, dynamic>{
          'p_fine_id': fine.id,
          'p_file_name': file.originalName,
          'p_file_path': path,
          'p_content_type': file.contentType,
        },
      );
      if (attached != true) {
        throw StateError('Не удалось привязать объяснительную');
      }
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
