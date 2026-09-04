import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AccountingBankTransaction {
  final String id;
  final DateTime date;
  final String direction;
  final double amount;
  final String counterparty;
  final String purpose;
  final String status;

  const AccountingBankTransaction({
    required this.id,
    required this.date,
    required this.direction,
    required this.amount,
    required this.counterparty,
    required this.purpose,
    required this.status,
  });

  factory AccountingBankTransaction.fromMap(Map<String, dynamic> map) {
    return AccountingBankTransaction(
      id: map['id']?.toString() ?? '',
      date: DateTime.tryParse(map['operation_date']?.toString() ?? '') ??
          DateTime.now(),
      direction: map['direction']?.toString() ?? 'out',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      counterparty: map['counterparty_name']?.toString() ?? '',
      purpose: map['purpose']?.toString() ?? '',
      status: map['status']?.toString() ?? 'new',
    );
  }
}

class AccountingBankImportRow {
  final DateTime date;
  final String direction;
  final double amount;
  final String counterparty;
  final String purpose;
  final String bankReference;

  const AccountingBankImportRow({
    required this.date,
    required this.direction,
    required this.amount,
    required this.counterparty,
    required this.purpose,
    this.bankReference = '',
  });
}

class AccountingBankAccount {
  final String id;
  final String name;
  final double balance;
  final DateTime updatedAt;

  const AccountingBankAccount({
    required this.id,
    required this.name,
    required this.balance,
    required this.updatedAt,
  });

  factory AccountingBankAccount.fromMap(Map<String, dynamic> map) {
    return AccountingBankAccount(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Основной счёт',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      updatedAt:
          DateTime.tryParse(map['balance_updated_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}

class AccountingDocumentFile {
  final String id;
  final String bucket;
  final String fileName;
  final String filePath;
  final String contentType;

  const AccountingDocumentFile({
    required this.id,
    required this.bucket,
    required this.fileName,
    required this.filePath,
    required this.contentType,
  });

  factory AccountingDocumentFile.fromMap(Map<String, dynamic> map) {
    return AccountingDocumentFile(
      id: map['id']?.toString() ?? '',
      bucket: map['bucket']?.toString() ?? 'accounting-documents',
      fileName: map['file_name']?.toString() ?? '',
      filePath: map['file_path']?.toString() ?? '',
      contentType: map['content_type']?.toString() ?? '',
    );
  }
}

class AccountingPrimaryDocument {
  final String id;
  final String documentType;
  final String number;
  final DateTime date;
  final String counterparty;
  final String objectName;
  final double amount;
  final double vatAmount;
  final String invoiceNumber;
  final DateTime? invoiceDate;
  final String status;
  final String comment;
  final List<AccountingDocumentFile> files;

  const AccountingPrimaryDocument({
    required this.id,
    required this.documentType,
    required this.number,
    required this.date,
    required this.counterparty,
    required this.objectName,
    required this.amount,
    required this.vatAmount,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.status,
    required this.comment,
    this.files = const [],
  });

  factory AccountingPrimaryDocument.fromMap(Map<String, dynamic> map) {
    final rawFiles = map['accounting_document_files'];
    final files = rawFiles is List
        ? rawFiles
            .whereType<Map>()
            .map(
              (e) => AccountingDocumentFile.fromMap(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : const <AccountingDocumentFile>[];
    return AccountingPrimaryDocument(
      id: map['id']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? 'purchase',
      number: map['document_number']?.toString() ?? '',
      date: DateTime.tryParse(map['document_date']?.toString() ?? '') ??
          DateTime.now(),
      counterparty: map['counterparty_name']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      vatAmount: (map['vat_amount'] as num?)?.toDouble() ?? 0,
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      invoiceDate: DateTime.tryParse(map['invoice_date']?.toString() ?? ''),
      status: map['status']?.toString() ?? 'draft',
      comment: map['comment']?.toString() ?? '',
      files: files,
    );
  }
}

class AccountingCounterparty {
  final String id;
  final String name;
  final String inn;
  final String kpp;
  final String contractNumber;
  final DateTime? contractDate;

  const AccountingCounterparty({
    required this.id,
    required this.name,
    required this.inn,
    required this.kpp,
    required this.contractNumber,
    required this.contractDate,
  });

  factory AccountingCounterparty.fromMap(Map<String, dynamic> map) {
    return AccountingCounterparty(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      inn: map['inn']?.toString() ?? '',
      kpp: map['kpp']?.toString() ?? '',
      contractNumber: map['contract_number']?.toString() ?? '',
      contractDate: DateTime.tryParse(map['contract_date']?.toString() ?? ''),
    );
  }
}

class AccountingNomenclature {
  final String id;
  final String name;
  final String kind;
  final String unit;
  final double? vatRate;
  final String comment;

  const AccountingNomenclature({
    required this.id,
    required this.name,
    required this.kind,
    required this.unit,
    required this.vatRate,
    required this.comment,
  });

  factory AccountingNomenclature.fromMap(Map<String, dynamic> map) {
    return AccountingNomenclature(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      kind: map['kind']?.toString() ?? 'service',
      unit: map['unit']?.toString() ?? '',
      vatRate: (map['vat_rate'] as num?)?.toDouble(),
      comment: map['comment']?.toString() ?? '',
    );
  }
}

class AccountingMaterialMovement {
  final String id;
  final DateTime date;
  final String objectName;
  final String materialName;
  final double quantity;
  final String unit;
  final double amount;
  final String documentNumber;

  const AccountingMaterialMovement({
    required this.id,
    required this.date,
    required this.objectName,
    required this.materialName,
    required this.quantity,
    required this.unit,
    required this.amount,
    required this.documentNumber,
  });

  factory AccountingMaterialMovement.fromMap(Map<String, dynamic> map) {
    return AccountingMaterialMovement(
      id: map['id']?.toString() ?? '',
      date: DateTime.tryParse(map['movement_date']?.toString() ?? '') ??
          DateTime.now(),
      objectName: map['object_name']?.toString() ?? '',
      materialName: map['material_name']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unit: map['unit']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      documentNumber: map['document_number']?.toString() ?? '',
    );
  }
}

class AccountingCalendarTask {
  final String id;
  final DateTime dueDate;
  final String title;
  final String kind;
  final String status;

  const AccountingCalendarTask({
    required this.id,
    required this.dueDate,
    required this.title,
    required this.kind,
    required this.status,
  });

  factory AccountingCalendarTask.fromMap(Map<String, dynamic> map) {
    return AccountingCalendarTask(
      id: map['id']?.toString() ?? '',
      dueDate: DateTime.tryParse(map['due_date']?.toString() ?? '') ??
          DateTime.now(),
      title: map['title']?.toString() ?? '',
      kind: map['kind']?.toString() ?? 'other',
      status: map['status']?.toString() ?? 'open',
    );
  }
}

class AccountingWorkbenchRepository {
  AccountingWorkbenchRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  static const String documentBucket = 'accounting-documents';
  final SupabaseClient _client;

  Future<List<AccountingBankTransaction>> fetchBankTransactions({
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _client.from('accounting_bank_transactions').select();
    if (from != null) query = query.gte('operation_date', _date(from));
    if (to != null) query = query.lte('operation_date', _date(to));
    final raw = await query.order('operation_date', ascending: false).limit(500);
    return (raw as List)
        .whereType<Map>()
        .map(
          (e) => AccountingBankTransaction.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AccountingBankAccount>> fetchBankAccounts() async {
    final raw = await _client
        .from('accounting_bank_accounts')
        .select()
        .order('name');
    return (raw as List)
        .whereType<Map>()
        .map(
          (e) => AccountingBankAccount.fromMap(Map<String, dynamic>.from(e)),
        )
        .toList(growable: false);
  }

  Future<void> setBankBalance({
    required double balance,
    String accountName = 'Основной счёт',
  }) async {
    final rows = await _client
        .from('accounting_bank_accounts')
        .select('id')
        .eq('name', accountName)
        .limit(1);
    final now = DateTime.now().toUtc().toIso8601String();
    if ((rows as List).isEmpty) {
      await _client.from('accounting_bank_accounts').insert({
        'name': accountName,
        'balance': balance,
        'balance_updated_at': now,
      });
    } else {
      final id = (rows.first as Map)['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await _client.from('accounting_bank_accounts').update({
          'balance': balance,
          'balance_updated_at': now,
          'updated_at': now,
        }).eq('id', id);
      }
    }
  }

  Future<int> importBankTransactions(
    List<AccountingBankImportRow> rows,
  ) async {
    if (rows.isEmpty) return 0;
    final existing = await fetchCounterparties();
    final names = <String>{
      ...existing.map((e) => e.name.trim().toLowerCase()),
    };
    for (final row in rows) {
      final name = row.counterparty.trim();
      final key = name.toLowerCase();
      if (name.isNotEmpty && !names.contains(key)) {
        await createCounterparty(name: name);
        names.add(key);
      }
    }
    await _client.from('accounting_bank_transactions').insert(
          rows
              .map(
                (row) => <String, dynamic>{
                  'operation_date': _date(row.date),
                  'direction': row.direction,
                  'amount': row.amount,
                  'counterparty_name': row.counterparty.trim(),
                  'purpose': row.purpose.trim(),
                  'bank_reference': row.bankReference.trim(),
                  'status': row.counterparty.trim().isEmpty
                      ? 'attention'
                      : 'matched',
                },
              )
              .toList(growable: false),
        );
    return rows.length;
  }

  Future<List<AccountingPrimaryDocument>> fetchDocuments({String? type}) async {
    var query = _client.from('accounting_primary_documents').select(
          '*,accounting_document_files(id,bucket,file_name,file_path,content_type,created_at)',
        );
    if (type != null) query = query.eq('document_type', type);
    final raw = await query.order('document_date', ascending: false).limit(500);
    return (raw as List)
        .whereType<Map>()
        .map(
          (e) => AccountingPrimaryDocument.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AccountingCounterparty>> fetchCounterparties() async {
    final raw = await _client
        .from('accounting_counterparties')
        .select()
        .order('name')
        .limit(1000);
    return (raw as List)
        .whereType<Map>()
        .map(
          (e) => AccountingCounterparty.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AccountingNomenclature>> fetchNomenclature() async {
    final raw = await _client
        .from('accounting_nomenclature')
        .select()
        .order('name')
        .limit(2000);
    return (raw as List)
        .whereType<Map>()
        .map(
          (e) => AccountingNomenclature.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AccountingMaterialMovement>> fetchMaterialMovements() async {
    final raw = await _client
        .from('accounting_material_movements')
        .select()
        .order('movement_date', ascending: false)
        .limit(500);
    return (raw as List)
        .whereType<Map>()
        .map(
          (e) => AccountingMaterialMovement.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AccountingCalendarTask>> fetchCalendarTasks({int limit = 50}) async {
    final raw = await _client
        .from('accounting_calendar_tasks')
        .select()
        .neq('status', 'done')
        .order('due_date')
        .limit(limit);
    return (raw as List)
        .whereType<Map>()
        .map(
          (e) => AccountingCalendarTask.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  Future<void> createBankTransaction({
    required DateTime date,
    required String direction,
    required double amount,
    required String counterparty,
    required String purpose,
  }) async {
    await _client.from('accounting_bank_transactions').insert({
      'operation_date': _date(date),
      'direction': direction,
      'amount': amount,
      'counterparty_name': counterparty.trim(),
      'purpose': purpose.trim(),
      'status': counterparty.trim().isEmpty ? 'attention' : 'matched',
    });
    if (counterparty.trim().isNotEmpty) {
      await _ensureCounterparty(counterparty.trim());
    }
  }

  Future<String> createDocument({
    required String documentType,
    required String number,
    required DateTime date,
    required String counterparty,
    required String objectName,
    required double amount,
    required double vatAmount,
    String invoiceNumber = '',
    DateTime? invoiceDate,
    String comment = '',
  }) async {
    await _ensureCounterparty(counterparty.trim());
    final raw = await _client
        .from('accounting_primary_documents')
        .insert({
          'document_type': documentType,
          'document_number': number.trim(),
          'document_date': _date(date),
          'counterparty_name': counterparty.trim(),
          'object_name': objectName.trim(),
          'amount': amount,
          'vat_amount': vatAmount,
          'invoice_number': invoiceNumber.trim(),
          'invoice_date': invoiceDate == null ? null : _date(invoiceDate),
          'comment': comment.trim(),
          'status': 'draft',
        })
        .select('id')
        .single();
    return raw['id']?.toString() ?? '';
  }

  Future<void> uploadDocumentFile({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final companyId = await _companyIdForDocument(documentId);
    if (companyId.isEmpty) throw StateError('Не удалось определить компанию');
    final safeName = _safeFileName(fileName);
    final filePath = '$companyId/$documentId/'
        '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final type = (contentType == null || contentType.trim().isEmpty)
        ? _contentType(fileName)
        : contentType.trim();
    await _client.storage.from(documentBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: type, upsert: false),
        );
    try {
      await _client.from('accounting_document_files').insert({
        'document_id': documentId,
        'company_id': companyId,
        'bucket': documentBucket,
        'file_path': filePath,
        'file_name': fileName.trim().isEmpty ? safeName : fileName.trim(),
        'content_type': type,
      });
    } catch (_) {
      await _client.storage.from(documentBucket).remove([filePath]);
      rethrow;
    }
  }

  Future<String> createDocumentFileSignedUrl(AccountingDocumentFile file) {
    return _client.storage.from(file.bucket).createSignedUrl(file.filePath, 1800);
  }

  Future<void> createCounterparty({
    required String name,
    String inn = '',
    String kpp = '',
    String contractNumber = '',
    DateTime? contractDate,
  }) async {
    await _client.from('accounting_counterparties').insert({
      'name': name.trim(),
      'inn': inn.trim(),
      'kpp': kpp.trim(),
      'contract_number': contractNumber.trim(),
      'contract_date': contractDate == null ? null : _date(contractDate),
    });
  }

  Future<void> createNomenclature({
    required String name,
    required String kind,
    String unit = '',
    double? vatRate,
    String comment = '',
  }) async {
    await _client.from('accounting_nomenclature').insert({
      'name': name.trim(),
      'kind': kind,
      'unit': unit.trim(),
      'vat_rate': vatRate,
      'comment': comment.trim(),
    });
  }

  Future<void> createMaterialWriteOff({
    required DateTime date,
    required String objectName,
    required String materialName,
    required double quantity,
    required String unit,
    required double amount,
    String documentNumber = '',
  }) async {
    await _client.from('accounting_material_movements').insert({
      'movement_date': _date(date),
      'movement_type': 'writeoff',
      'object_name': objectName.trim(),
      'material_name': materialName.trim(),
      'quantity': quantity,
      'unit': unit.trim(),
      'amount': amount,
      'document_number': documentNumber.trim(),
    });
  }

  Future<void> createCalendarTask({
    required DateTime dueDate,
    required String title,
    required String kind,
  }) async {
    await _client.from('accounting_calendar_tasks').insert({
      'due_date': _date(dueDate),
      'title': title.trim(),
      'kind': kind,
      'status': 'open',
    });
  }

  Future<void> completeCalendarTask(String id) async {
    await _client
        .from('accounting_calendar_tasks')
        .update({'status': 'done'}).eq('id', id);
  }

  Future<void> _ensureCounterparty(String name) async {
    if (name.isEmpty) return;
    final raw = await _client
        .from('accounting_counterparties')
        .select('id')
        .ilike('name', name)
        .limit(1);
    if ((raw as List).isEmpty) {
      await createCounterparty(name: name);
    }
  }

  Future<String> _companyIdForDocument(String documentId) async {
    final raw = await _client
        .from('accounting_primary_documents')
        .select('company_id')
        .eq('id', documentId)
        .single();
    return raw['company_id']?.toString() ?? '';
  }

  String _safeFileName(String value) {
    final clean = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return clean.isEmpty ? 'document' : clean;
  }

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.csv')) return 'text/csv';
    return 'application/octet-stream';
  }

  String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
