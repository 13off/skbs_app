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
      date: DateTime.tryParse(map['operation_date']?.toString() ?? '') ?? DateTime.now(),
      direction: map['direction']?.toString() ?? 'out',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      counterparty: map['counterparty_name']?.toString() ?? '',
      purpose: map['purpose']?.toString() ?? '',
      status: map['status']?.toString() ?? 'new',
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
  });

  factory AccountingPrimaryDocument.fromMap(Map<String, dynamic> map) {
    return AccountingPrimaryDocument(
      id: map['id']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? 'purchase',
      number: map['document_number']?.toString() ?? '',
      date: DateTime.tryParse(map['document_date']?.toString() ?? '') ?? DateTime.now(),
      counterparty: map['counterparty_name']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      vatAmount: (map['vat_amount'] as num?)?.toDouble() ?? 0,
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      invoiceDate: DateTime.tryParse(map['invoice_date']?.toString() ?? ''),
      status: map['status']?.toString() ?? 'draft',
      comment: map['comment']?.toString() ?? '',
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
      date: DateTime.tryParse(map['movement_date']?.toString() ?? '') ?? DateTime.now(),
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
      dueDate: DateTime.tryParse(map['due_date']?.toString() ?? '') ?? DateTime.now(),
      title: map['title']?.toString() ?? '',
      kind: map['kind']?.toString() ?? 'other',
      status: map['status']?.toString() ?? 'open',
    );
  }
}

class AccountingWorkbenchRepository {
  AccountingWorkbenchRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AccountingBankTransaction>> fetchBankTransactions({DateTime? from, DateTime? to}) async {
    var query = _client.from('accounting_bank_transactions').select();
    if (from != null) query = query.gte('operation_date', _date(from));
    if (to != null) query = query.lte('operation_date', _date(to));
    final raw = await query.order('operation_date', ascending: false).limit(500);
    return (raw as List)
        .whereType<Map>()
        .map((e) => AccountingBankTransaction.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<List<AccountingPrimaryDocument>> fetchDocuments({String? type}) async {
    var query = _client.from('accounting_primary_documents').select();
    if (type != null) query = query.eq('document_type', type);
    final raw = await query.order('document_date', ascending: false).limit(500);
    return (raw as List)
        .whereType<Map>()
        .map((e) => AccountingPrimaryDocument.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<List<AccountingCounterparty>> fetchCounterparties() async {
    final raw = await _client.from('accounting_counterparties').select().order('name').limit(1000);
    return (raw as List)
        .whereType<Map>()
        .map((e) => AccountingCounterparty.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<List<AccountingMaterialMovement>> fetchMaterialMovements() async {
    final raw = await _client.from('accounting_material_movements').select().order('movement_date', ascending: false).limit(500);
    return (raw as List)
        .whereType<Map>()
        .map((e) => AccountingMaterialMovement.fromMap(Map<String, dynamic>.from(e)))
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
        .map((e) => AccountingCalendarTask.fromMap(Map<String, dynamic>.from(e)))
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
      'status': 'new',
    });
  }

  Future<void> createDocument({
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
    await _client.from('accounting_primary_documents').insert({
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
    });
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
    await _client.from('accounting_calendar_tasks').update({'status': 'done'}).eq('id', id);
  }

  String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
