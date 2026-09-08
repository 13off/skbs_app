import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'accounting_workbench_repository.dart';

class AccountingDetailRepository {
  AccountingDetailRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client,
        _workbench = AccountingWorkbenchRepository(
          client ?? Supabase.instance.client,
        );

  final SupabaseClient _client;
  final AccountingWorkbenchRepository _workbench;

  Future<AccountingPrimaryDocument?> fetchDocument(String documentId) async {
    final id = documentId.trim();
    if (id.isEmpty) return null;
    final raw = await _client
        .from('accounting_primary_documents')
        .select(
          '*,accounting_document_files(id,bucket,file_name,file_path,content_type,created_at)',
        )
        .eq('id', id)
        .maybeSingle();
    if (raw == null) return null;
    return AccountingPrimaryDocument.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> updateDocument({
    required String documentId,
    required String documentType,
    required String number,
    required DateTime date,
    required String counterparty,
    required String objectName,
    required double amount,
    required double vatAmount,
    required String invoiceNumber,
    DateTime? invoiceDate,
    required String status,
    required String comment,
  }) async {
    final id = documentId.trim();
    if (id.isEmpty) throw ArgumentError('Пустой ID документа');
    await _client.from('accounting_primary_documents').update({
      'document_type': documentType,
      'document_number': number.trim(),
      'document_date': _date(date),
      'counterparty_name': counterparty.trim(),
      'object_name': objectName.trim(),
      'amount': amount,
      'vat_amount': vatAmount,
      'invoice_number': invoiceNumber.trim(),
      'invoice_date': invoiceDate == null ? null : _date(invoiceDate),
      'status': status,
      'comment': comment.trim(),
    }).eq('id', id);
  }

  Future<void> addDocumentFile({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) {
    return _workbench.uploadDocumentFile(
      documentId: documentId,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<void> deleteDocumentFile(AccountingDocumentFile file) async {
    if (file.id.trim().isEmpty) throw ArgumentError('Пустой ID файла');
    await _client.from('accounting_document_files').delete().eq('id', file.id);
    if (file.filePath.trim().isNotEmpty) {
      await _client.storage.from(file.bucket).remove([file.filePath]);
    }
  }

  Future<void> replaceDocumentFile({
    required String documentId,
    required AccountingDocumentFile previous,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    await addDocumentFile(
      documentId: documentId,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
    await deleteDocumentFile(previous);
  }

  Future<String> createDocumentFileSignedUrl(AccountingDocumentFile file) {
    return _workbench.createDocumentFileSignedUrl(file);
  }

  Future<AccountingCalendarTask?> fetchCalendarTask(String taskId) async {
    final id = taskId.trim();
    if (id.isEmpty) return null;
    final raw = await _client
        .from('accounting_calendar_tasks')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (raw == null) return null;
    return AccountingCalendarTask.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> updateCalendarTask({
    required String taskId,
    required DateTime dueDate,
    required String title,
    required String kind,
    required String status,
  }) async {
    final id = taskId.trim();
    if (id.isEmpty) throw ArgumentError('Пустой ID задачи');
    await _client.from('accounting_calendar_tasks').update({
      'due_date': _date(dueDate),
      'title': title.trim(),
      'kind': kind,
      'status': status,
    }).eq('id', id);
  }

  String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
