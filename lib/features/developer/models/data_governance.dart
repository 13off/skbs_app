class DataGovernanceObject {
  final String id;
  final String name;
  final bool isActive;

  const DataGovernanceObject({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory DataGovernanceObject.fromJson(Map<String, dynamic> json) {
    return DataGovernanceObject(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }
}

class DataGovernanceTrashEntry {
  final String entityType;
  final String entityId;
  final String title;
  final String subtitle;
  final String? objectId;
  final String objectName;
  final DateTime? deletedAt;
  final String deleteReason;
  final String deletedByName;
  final Map<String, dynamic> metadata;

  const DataGovernanceTrashEntry({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.subtitle,
    required this.objectId,
    required this.objectName,
    required this.deletedAt,
    required this.deleteReason,
    required this.deletedByName,
    required this.metadata,
  });

  factory DataGovernanceTrashEntry.fromJson(Map<String, dynamic> json) {
    return DataGovernanceTrashEntry(
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      objectId: _nullableText(json['object_id']),
      objectName: json['object_name']?.toString() ?? '',
      deletedAt: DateTime.tryParse(json['deleted_at']?.toString() ?? ''),
      deleteReason: json['delete_reason']?.toString() ?? '',
      deletedByName: json['deleted_by_name']?.toString() ?? '',
      metadata: _map(json['metadata']),
    );
  }

  String get typeTitle => entityTypeTitle(entityType);
}

class DataGovernanceAuditEntry {
  final String auditId;
  final String entityType;
  final String entityId;
  final String action;
  final String actorName;
  final DateTime? createdAt;
  final String? objectId;
  final String objectName;
  final Map<String, dynamic> beforeValue;
  final Map<String, dynamic> afterValue;
  final Map<String, dynamic> metadata;

  const DataGovernanceAuditEntry({
    required this.auditId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actorName,
    required this.createdAt,
    required this.objectId,
    required this.objectName,
    required this.beforeValue,
    required this.afterValue,
    required this.metadata,
  });

  factory DataGovernanceAuditEntry.fromJson(Map<String, dynamic> json) {
    return DataGovernanceAuditEntry(
      auditId: json['audit_id']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      objectId: _nullableText(json['object_id']),
      objectName: json['object_name']?.toString() ?? '',
      beforeValue: _map(json['before_value']),
      afterValue: _map(json['after_value']),
      metadata: _map(json['metadata']),
    );
  }

  String get semanticAction {
    final value = metadata['_semantic_action']?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
    return switch (action.toUpperCase()) {
      'INSERT' => 'created',
      'UPDATE' => 'updated',
      'DELETE' => 'deleted',
      _ => action.toLowerCase(),
    };
  }

  String get typeTitle => entityTypeTitle(entityType);
}

class DataGovernanceCenter {
  final List<DataGovernanceObject> objects;
  final List<DataGovernanceTrashEntry> trash;
  final List<DataGovernanceAuditEntry> audit;

  const DataGovernanceCenter({
    required this.objects,
    required this.trash,
    required this.audit,
  });

  factory DataGovernanceCenter.fromJson(Map<String, dynamic> json) {
    return DataGovernanceCenter(
      objects: _maps(json['objects'])
          .map(DataGovernanceObject.fromJson)
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList(),
      trash: _maps(json['trash'])
          .map(DataGovernanceTrashEntry.fromJson)
          .where((item) => item.entityType.isNotEmpty && item.entityId.isNotEmpty)
          .toList(),
      audit: _maps(json['audit'])
          .map(DataGovernanceAuditEntry.fromJson)
          .where((item) => item.entityType.isNotEmpty)
          .toList(),
    );
  }
}

const dataGovernanceEntityTypes = <String, String>{
  'task': 'Задачи',
  'attendance': 'Табель',
  'payment': 'Выплаты',
  'employee': 'Сотрудники',
  'object': 'Объекты',
  'milestone': 'Цели и этапы',
  'legal_document': 'Документы',
  'employees': 'Сотрудники',
  'objects': 'Объекты',
  'payments': 'Выплаты',
  'project_milestones': 'Цели и этапы',
  'document_templates': 'Шаблоны документов',
  'legal_documents': 'Документы',
};

String entityTypeTitle(String value) {
  return dataGovernanceEntityTypes[value] ?? value;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
