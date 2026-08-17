import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/user_repository.dart';

Map<String, dynamic> _legalOpsMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : const <String, dynamic>{};

List<dynamic> _legalOpsList(dynamic value) =>
    value is List ? value : const <dynamic>[];

DateTime? _legalOpsDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  return raw.isEmpty ? null : DateTime.tryParse(raw)?.toLocal();
}

String? _legalOpsNullable(String value) {
  final clean = value.trim();
  return clean.isEmpty ? null : clean;
}

class LegalEmployeeRequirement {
  final String code;
  final String title;
  final String documentGroup;
  final bool required;
  final bool applicable;
  final bool present;
  final String matchedTitle;
  final String matchedSource;
  final int priority;
  final int sortOrder;

  const LegalEmployeeRequirement({
    required this.code,
    required this.title,
    required this.documentGroup,
    required this.required,
    required this.applicable,
    required this.present,
    required this.matchedTitle,
    required this.matchedSource,
    required this.priority,
    required this.sortOrder,
  });

  factory LegalEmployeeRequirement.fromMap(Map<String, dynamic> map) {
    return LegalEmployeeRequirement(
      code: map['requirement_code']?.toString() ?? '',
      title: map['requirement_title']?.toString() ?? '',
      documentGroup: map['document_group']?.toString() ?? 'other',
      required: map['is_required'] == true,
      applicable: map['applicable'] == true,
      present: map['present'] == true,
      matchedTitle: map['matched_title']?.toString() ?? '',
      matchedSource: map['matched_source']?.toString() ?? '',
      priority: int.tryParse(map['priority']?.toString() ?? '') ?? 100,
      sortOrder: int.tryParse(map['sort_order']?.toString() ?? '') ?? 100,
    );
  }
}

class LegalObjectProfile {
  final String objectId;
  final String objectName;
  final String address;
  final String comment;
  final bool isActive;
  final String customerCounterpartyId;
  final String customerName;
  final String mainContractDocumentId;
  final String mainContractTitle;
  final String responsibleUserId;
  final double? contractValue;
  final DateTime? contractStart;
  final DateTime? contractEnd;
  final String notes;

  const LegalObjectProfile({
    required this.objectId,
    required this.objectName,
    required this.address,
    required this.comment,
    required this.isActive,
    required this.customerCounterpartyId,
    required this.customerName,
    required this.mainContractDocumentId,
    required this.mainContractTitle,
    required this.responsibleUserId,
    required this.contractValue,
    required this.contractStart,
    required this.contractEnd,
    required this.notes,
  });

  factory LegalObjectProfile.fromMap(Map<String, dynamic> map) {
    return LegalObjectProfile(
      objectId: map['object_id']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      comment: map['comment']?.toString() ?? '',
      isActive: map['is_active'] == true,
      customerCounterpartyId:
          map['customer_counterparty_id']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? '',
      mainContractDocumentId:
          map['main_contract_document_id']?.toString() ?? '',
      mainContractTitle: map['main_contract_title']?.toString() ?? '',
      responsibleUserId: map['responsible_user_id']?.toString() ?? '',
      contractValue: double.tryParse(map['contract_value']?.toString() ?? ''),
      contractStart: _legalOpsDate(map['contract_start']),
      contractEnd: _legalOpsDate(map['contract_end']),
      notes: map['notes']?.toString() ?? '',
    );
  }
}

class LegalTodayItem {
  final String itemType;
  final String entityType;
  final String entityId;
  final String title;
  final String subtitle;
  final DateTime? dueAt;
  final String severity;
  final String employeeId;
  final String objectId;
  final String actionCode;
  final int sortKey;

  const LegalTodayItem({
    required this.itemType,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.subtitle,
    required this.dueAt,
    required this.severity,
    required this.employeeId,
    required this.objectId,
    required this.actionCode,
    required this.sortKey,
  });

  factory LegalTodayItem.fromMap(Map<String, dynamic> map) {
    return LegalTodayItem(
      itemType: map['item_type']?.toString() ?? '',
      entityType: map['entity_type']?.toString() ?? '',
      entityId: map['entity_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      dueAt: _legalOpsDate(map['due_at']),
      severity: map['severity']?.toString() ?? 'info',
      employeeId: map['employee_id']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      actionCode: map['action_code']?.toString() ?? '',
      sortKey: int.tryParse(map['sort_key']?.toString() ?? '') ?? 100,
    );
  }
}

class LegalProcessEvent {
  final String id;
  final String matterId;
  final String kind;
  final String title;
  final DateTime? eventAt;
  final DateTime? dueAt;
  final String status;
  final String result;
  final DateTime? createdAt;

  const LegalProcessEvent({
    required this.id,
    required this.matterId,
    required this.kind,
    required this.title,
    required this.eventAt,
    required this.dueAt,
    required this.status,
    required this.result,
    required this.createdAt,
  });

  factory LegalProcessEvent.fromMap(Map<String, dynamic> map) {
    return LegalProcessEvent(
      id: map['id']?.toString() ?? '',
      matterId: map['matter_id']?.toString() ?? '',
      kind: map['event_kind']?.toString() ?? 'note',
      title: map['title']?.toString() ?? '',
      eventAt: _legalOpsDate(map['event_at']),
      dueAt: _legalOpsDate(map['due_at']),
      status: map['status']?.toString() ?? 'scheduled',
      result: map['result']?.toString() ?? '',
      createdAt: _legalOpsDate(map['created_at']),
    );
  }
}

class LegalQualityIssue {
  final String issueType;
  final String severity;
  final String entityType;
  final String entityId;
  final String title;
  final String details;

  const LegalQualityIssue({
    required this.issueType,
    required this.severity,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.details,
  });

  factory LegalQualityIssue.fromMap(Map<String, dynamic> map) {
    return LegalQualityIssue(
      issueType: map['issue_type']?.toString() ?? '',
      severity: map['severity']?.toString() ?? 'info',
      entityType: map['entity_type']?.toString() ?? '',
      entityId: map['entity_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
    );
  }
}

abstract final class LegalOperationsRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static String get _companyId =>
      UserRepository.cachedProfile?.activeCompanyId.trim() ?? '';

  static Future<List<LegalEmployeeRequirement>> fetchEmployeeCompleteness(
    String employeeId,
  ) async {
    final response = await _client.rpc(
      'legal_employee_completeness',
      params: <String, dynamic>{'p_employee_id': employeeId},
    );
    return _legalOpsList(response)
        .map(
          (value) => LegalEmployeeRequirement.fromMap(_legalOpsMap(value)),
        )
        .where((item) => item.code.isNotEmpty)
        .toList(growable: false);
  }

  static Future<LegalObjectProfile> fetchObjectProfile(String objectId) async {
    final response = await _client.rpc(
      'legal_object_profile',
      params: <String, dynamic>{'p_object_id': objectId},
    );
    final map = _legalOpsMap(response);
    if (map.isEmpty) throw StateError('Досье объекта не найдено');
    return LegalObjectProfile.fromMap(map);
  }

  static Future<void> saveObjectProfile({
    required String objectId,
    String customerCounterpartyId = '',
    String mainContractDocumentId = '',
    String responsibleUserId = '',
    double? contractValue,
    DateTime? contractStart,
    DateTime? contractEnd,
    String notes = '',
  }) async {
    final companyId = _companyId;
    if (companyId.isEmpty) throw StateError('Компания не выбрана');
    await _client.from('legal_object_profiles').upsert(
      <String, dynamic>{
        'object_id': objectId,
        'company_id': companyId,
        'customer_counterparty_id':
            _legalOpsNullable(customerCounterpartyId),
        'main_contract_document_id':
            _legalOpsNullable(mainContractDocumentId),
        'responsible_user_id': _legalOpsNullable(responsibleUserId),
        'contract_value': contractValue,
        'contract_start': contractStart == null
            ? null
            : '${contractStart.year.toString().padLeft(4, '0')}-${contractStart.month.toString().padLeft(2, '0')}-${contractStart.day.toString().padLeft(2, '0')}',
        'contract_end': contractEnd == null
            ? null
            : '${contractEnd.year.toString().padLeft(4, '0')}-${contractEnd.month.toString().padLeft(2, '0')}-${contractEnd.day.toString().padLeft(2, '0')}',
        'notes': notes.trim(),
        'updated_by': _client.auth.currentUser?.id,
      },
      onConflict: 'object_id',
    );
  }

  static Future<List<LegalTodayItem>> fetchTodayItems() async {
    final response = await _client.rpc('legal_today_items');
    final items = _legalOpsList(response)
        .map((value) => LegalTodayItem.fromMap(_legalOpsMap(value)))
        .where((item) => item.entityId.isNotEmpty)
        .toList();
    items.sort((a, b) {
      final bySort = a.sortKey.compareTo(b.sortKey);
      if (bySort != 0) return bySort;
      final aDue = a.dueAt ?? DateTime(9999);
      final bDue = b.dueAt ?? DateTime(9999);
      return aDue.compareTo(bDue);
    });
    return items;
  }

  static Future<List<LegalProcessEvent>> fetchProcessEvents(
    String matterId,
  ) async {
    final rows = await _client
        .from('legal_matter_process_events')
        .select(
          'id, matter_id, event_kind, title, event_at, due_at, status, result, created_at',
        )
        .eq('matter_id', matterId)
        .order('created_at', ascending: true);
    final items = rows
        .map(
          (value) => LegalProcessEvent.fromMap(
            Map<String, dynamic>.from(value),
          ),
        )
        .toList();
    items.sort((a, b) {
      final left = a.eventAt ?? a.dueAt ?? a.createdAt ?? DateTime(9999);
      final right = b.eventAt ?? b.dueAt ?? b.createdAt ?? DateTime(9999);
      return left.compareTo(right);
    });
    return items;
  }

  static Future<void> saveProcessEvent({
    String? id,
    required String matterId,
    required String kind,
    required String title,
    DateTime? eventAt,
    DateTime? dueAt,
    String status = 'scheduled',
    String result = '',
  }) async {
    final companyId = _companyId;
    if (companyId.isEmpty) throw StateError('Компания не выбрана');
    final payload = <String, dynamic>{
      'company_id': companyId,
      'matter_id': matterId,
      'event_kind': kind,
      'title': title.trim(),
      'event_at': eventAt?.toUtc().toIso8601String(),
      'due_at': dueAt?.toUtc().toIso8601String(),
      'status': status,
      'result': result.trim(),
      'updated_by': _client.auth.currentUser?.id,
    };
    if ((id ?? '').trim().isEmpty) {
      payload['created_by'] = _client.auth.currentUser?.id;
      await _client.from('legal_matter_process_events').insert(payload);
    } else {
      await _client
          .from('legal_matter_process_events')
          .update(payload)
          .eq('id', id!);
    }
  }

  static Future<void> deleteProcessEvent(String id) async {
    await _client.from('legal_matter_process_events').delete().eq('id', id);
  }

  static Future<List<LegalQualityIssue>> fetchQualityReport() async {
    final response = await _client.rpc('legal_quality_report');
    return _legalOpsList(response)
        .map((value) => LegalQualityIssue.fromMap(_legalOpsMap(value)))
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
  }
}
