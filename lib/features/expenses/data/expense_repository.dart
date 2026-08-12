import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../../../data/attendance_repository.dart';
import '../../../data/payment_repository.dart';

class ExpenseCategoryData {
  final String id;
  final String name;
  final int sortOrder;

  const ExpenseCategoryData({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  factory ExpenseCategoryData.fromMap(Map<String, dynamic> map) {
    return ExpenseCategoryData(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExpenseObjectData {
  final String id;
  final String name;
  final bool isActive;

  const ExpenseObjectData({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory ExpenseObjectData.fromMap(Map<String, dynamic> map) {
    return ExpenseObjectData(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class ExpenseAttachmentData {
  final String id;
  final String bucket;
  final String fileName;
  final String filePath;
  final String contentType;
  final bool isEditable;

  const ExpenseAttachmentData({
    required this.id,
    required this.bucket,
    required this.fileName,
    required this.filePath,
    required this.contentType,
    required this.isEditable,
  });

  factory ExpenseAttachmentData.fromMap(Map<String, dynamic> map) {
    return ExpenseAttachmentData(
      id: map['id']?.toString() ?? '',
      bucket: map['bucket']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? '',
      filePath: map['file_path']?.toString() ?? '',
      contentType: map['content_type']?.toString() ?? '',
      isEditable: map['is_editable'] as bool? ?? false,
    );
  }
}

class ExpenseItemData {
  final String id;
  final String sourceType;
  final DateTime date;
  final String name;
  final double amount;
  final String? categoryId;
  final String categoryName;
  final String? objectId;
  final String? objectName;
  final String counterpartyName;
  final String comment;
  final String? paymentType;
  final bool isEditable;
  final List<ExpenseAttachmentData> attachments;

  const ExpenseItemData({
    required this.id,
    required this.sourceType,
    required this.date,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.objectId,
    required this.objectName,
    required this.counterpartyName,
    required this.comment,
    required this.paymentType,
    required this.isEditable,
    required this.attachments,
  });

  bool get isPayment => sourceType == 'payment';

  factory ExpenseItemData.fromMap(Map<String, dynamic> map) {
    final rawAttachments = map['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
            .whereType<Map>()
            .map(
              (item) => ExpenseAttachmentData.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((item) => item.filePath.isNotEmpty && item.bucket.isNotEmpty)
            .toList(growable: false)
        : const <ExpenseAttachmentData>[];

    return ExpenseItemData(
      id: map['id']?.toString() ?? '',
      sourceType: map['source_type']?.toString() ?? 'manual',
      date: DateTime.tryParse(map['expense_date']?.toString() ?? '') ??
          DateTime.now(),
      name: map['name']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      categoryId: map['category_id']?.toString(),
      categoryName: map['category_name']?.toString() ?? 'Без статьи',
      objectId: map['object_id']?.toString(),
      objectName: map['object_name']?.toString(),
      counterpartyName: map['counterparty_name']?.toString() ?? '',
      comment: map['comment']?.toString() ?? '',
      paymentType: map['payment_type']?.toString(),
      isEditable: map['is_editable'] as bool? ?? false,
      attachments: attachments,
    );
  }
}

class ExpensesSnapshot {
  final List<ExpenseCategoryData> categories;
  final List<ExpenseObjectData> objects;
  final List<ExpenseItemData> rows;

  const ExpensesSnapshot({
    required this.categories,
    required this.objects,
    required this.rows,
  });

  factory ExpensesSnapshot.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> maps(String key) {
      final value = map[key];
      if (value is! List) return const <Map<String, dynamic>>[];
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    return ExpensesSnapshot(
      categories: maps('categories')
          .map(ExpenseCategoryData.fromMap)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      objects: maps('objects')
          .map(ExpenseObjectData.fromMap)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      rows: maps('rows')
          .map(ExpenseItemData.fromMap)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class CreatedExpenseData {
  final String id;
  final String companyId;

  const CreatedExpenseData({required this.id, required this.companyId});
}

class EditablePaymentData {
  final String id;
  final String employeeId;
  final int periodYear;
  final int periodMonth;
  final DateTime paymentDate;
  final double amount;
  final String paymentType;
  final String comment;

  const EditablePaymentData({
    required this.id,
    required this.employeeId,
    required this.periodYear,
    required this.periodMonth,
    required this.paymentDate,
    required this.amount,
    required this.paymentType,
    required this.comment,
  });

  factory EditablePaymentData.fromMap(Map<String, dynamic> map) {
    return EditablePaymentData(
      id: map['id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      periodYear: (map['period_year'] as num?)?.toInt() ?? 0,
      periodMonth: (map['period_month'] as num?)?.toInt() ?? 0,
      paymentDate:
          DateTime.tryParse(map['payment_date']?.toString() ?? '') ??
          DateTime.now(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paymentType: map['payment_type']?.toString() ?? 'advance',
      comment: map['comment']?.toString() ?? '',
    );
  }
}

class ExpenseRepository {
  ExpenseRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  static const String expenseReceiptsBucket = 'expense-receipts';

  final SupabaseClient _client;

  String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _safeFileName(String value) {
    final clean = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return clean.isEmpty ? 'receipt' : clean;
  }

  String contentTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<ExpensesSnapshot> fetchSnapshot({
    required DateTime from,
    required DateTime to,
  }) async {
    final raw = await _client.rpc(
      'get_expenses_center',
      params: <String, dynamic>{
        'p_start_date': _date(from),
        'p_end_date': _date(to),
      },
    );
    if (raw is! Map) {
      return const ExpensesSnapshot(categories: [], objects: [], rows: []);
    }
    return ExpensesSnapshot.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<List<ExpenseCategoryData>> fetchCategories() async {
    final raw = await _client
        .from('expense_categories')
        .select('id,name,sort_order')
        .order('sort_order')
        .order('name');
    return (raw as List)
        .whereType<Map>()
        .map(
          (item) => ExpenseCategoryData.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<void> createCategory(String name) async {
    await _client.from('expense_categories').insert(<String, dynamic>{
      'name': name.trim(),
    });
  }

  Future<void> updateCategory(String id, String name) async {
    await _client.from('expense_categories').update(<String, dynamic>{
      'name': name.trim(),
    }).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('expense_categories').delete().eq('id', id);
  }

  Future<CreatedExpenseData> createExpense({
    required String name,
    required double amount,
    required DateTime date,
    String? categoryId,
    String? objectId,
    String counterpartyName = '',
    String comment = '',
  }) async {
    final raw = await _client
        .from('expenses')
        .insert(<String, dynamic>{
          'name': name.trim(),
          'amount': amount,
          'expense_date': _date(date),
          'category_id': categoryId,
          'object_id': objectId,
          'counterparty_name': counterpartyName.trim(),
          'comment': comment.trim(),
        })
        .select('id,company_id')
        .single();
    return CreatedExpenseData(
      id: raw['id']?.toString() ?? '',
      companyId: raw['company_id']?.toString() ?? '',
    );
  }

  Future<void> updateExpense({
    required String id,
    required String name,
    required double amount,
    required DateTime date,
    String? categoryId,
    String? objectId,
    String counterpartyName = '',
    String comment = '',
  }) async {
    await _client.from('expenses').update(<String, dynamic>{
      'name': name.trim(),
      'amount': amount,
      'expense_date': _date(date),
      'category_id': categoryId,
      'object_id': objectId,
      'counterparty_name': counterpartyName.trim(),
      'comment': comment.trim(),
    }).eq('id', id);
  }

  Future<EditablePaymentData> fetchPaymentForEdit(String paymentId) async {
    final raw = await _client
        .from('payments')
        .select(
          'id,employee_id,period_year,period_month,payment_date,amount,payment_type,comment',
        )
        .eq('id', paymentId)
        .single();
    return EditablePaymentData.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> updatePayment({
    required String id,
    required String employeeId,
    required int periodYear,
    required int periodMonth,
    required DateTime paymentDate,
    required double amount,
    required String paymentType,
    required String comment,
  }) async {
    await _client.from('payments').update(<String, dynamic>{
      'period_year': periodYear,
      'period_month': periodMonth,
      'payment_date': _date(paymentDate),
      'amount': amount,
      'payment_type': paymentType.trim(),
      'comment': comment.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);

    if (employeeId.trim().isEmpty) {
      PaymentRepository.clearCache();
    } else {
      PaymentRepository.clearEmployeePaymentsCache(employeeId);
    }
    AttendanceRepository.clearCache();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.payments},
      context: <String, dynamic>{
        'table': 'payments',
        'employee_id': employeeId.trim(),
        'period_year': periodYear,
        'period_month': periodMonth,
      },
    );
  }

  Future<void> deletePayment(String paymentId) async {
    final raw = await _client
        .from('payments')
        .select('employee_id')
        .eq('id', paymentId)
        .single();
    await PaymentRepository.deletePayment(
      paymentId,
      employeeId: raw['employee_id']?.toString(),
    );
  }

  Future<String> _companyIdForExpense(String expenseId) async {
    final raw = await _client
        .from('expenses')
        .select('company_id')
        .eq('id', expenseId)
        .single();
    return raw['company_id']?.toString() ?? '';
  }

  Future<void> uploadReceipt({
    required String expenseId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final companyId = await _companyIdForExpense(expenseId);
    if (companyId.isEmpty) throw StateError('Не удалось определить компанию');

    final safeName = _safeFileName(fileName);
    final filePath = '$companyId/$expenseId/'
        '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final type = (contentType == null || contentType.trim().isEmpty)
        ? contentTypeForFileName(fileName)
        : contentType.trim();

    await _client.storage.from(expenseReceiptsBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: type, upsert: false),
        );
    try {
      await _client.from('expense_receipts').insert(<String, dynamic>{
        'expense_id': expenseId,
        'company_id': companyId,
        'file_name': fileName.trim().isEmpty ? safeName : fileName.trim(),
        'file_path': filePath,
        'content_type': type,
      });
    } catch (_) {
      await _client.storage.from(expenseReceiptsBucket).remove([filePath]);
      rethrow;
    }
  }

  Future<String> createReceiptSignedUrl(ExpenseAttachmentData receipt) {
    return _client.storage
        .from(receipt.bucket)
        .createSignedUrl(receipt.filePath, 60 * 30);
  }

  Future<void> deleteReceipt(ExpenseAttachmentData receipt) async {
    if (!receipt.isEditable || receipt.bucket != expenseReceiptsBucket) return;
    await _client.storage.from(receipt.bucket).remove([receipt.filePath]);
    await _client.from('expense_receipts').delete().eq('id', receipt.id);
  }

  Future<void> deleteExpense(String id) async {
    final raw = await _client
        .from('expense_receipts')
        .select('file_path')
        .eq('expense_id', id);
    final paths = (raw as List)
        .whereType<Map>()
        .map((row) => row['file_path']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (paths.isNotEmpty) {
      await _client.storage.from(expenseReceiptsBucket).remove(paths);
    }
    await _client.from('expenses').delete().eq('id', id);
  }
}
