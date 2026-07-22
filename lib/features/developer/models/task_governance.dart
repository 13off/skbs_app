class TaskGovernanceObject {
  final String id;
  final String name;
  final bool isActive;

  const TaskGovernanceObject({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory TaskGovernanceObject.fromJson(Map<String, dynamic> json) {
    return TaskGovernanceObject(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }
}

class DeletedTaskEntry {
  final String id;
  final DateTime? taskDate;
  final String objectId;
  final String objectName;
  final String axes;
  final String work;
  final String status;
  final DateTime? deletedAt;
  final String deletedByName;
  final String deleteReason;

  const DeletedTaskEntry({
    required this.id,
    required this.taskDate,
    required this.objectId,
    required this.objectName,
    required this.axes,
    required this.work,
    required this.status,
    required this.deletedAt,
    required this.deletedByName,
    required this.deleteReason,
  });

  factory DeletedTaskEntry.fromJson(Map<String, dynamic> json) {
    return DeletedTaskEntry(
      id: json['id']?.toString() ?? '',
      taskDate: DateTime.tryParse(json['task_date']?.toString() ?? ''),
      objectId: json['object_id']?.toString() ?? '',
      objectName: json['object_name']?.toString() ?? '',
      axes: json['axes']?.toString() ?? '',
      work: json['work']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      deletedAt: DateTime.tryParse(json['deleted_at']?.toString() ?? '')
          ?.toLocal(),
      deletedByName: json['deleted_by_name']?.toString() ?? '',
      deleteReason: json['delete_reason']?.toString() ?? '',
    );
  }
}

class TaskActionAuditEntry {
  final int id;
  final String taskId;
  final String objectId;
  final String objectName;
  final DateTime? taskDate;
  final String action;
  final String actorName;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> beforeValue;
  final Map<String, dynamic> afterValue;

  const TaskActionAuditEntry({
    required this.id,
    required this.taskId,
    required this.objectId,
    required this.objectName,
    required this.taskDate,
    required this.action,
    required this.actorName,
    required this.createdAt,
    required this.metadata,
    required this.beforeValue,
    required this.afterValue,
  });

  factory TaskActionAuditEntry.fromJson(Map<String, dynamic> json) {
    return TaskActionAuditEntry(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      taskId: json['task_id']?.toString() ?? '',
      objectId: json['object_id']?.toString() ?? '',
      objectName: json['object_name']?.toString() ?? '',
      taskDate: DateTime.tryParse(json['task_date']?.toString() ?? ''),
      action: json['action']?.toString() ?? 'updated',
      actorName: json['actor_name']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')
          ?.toLocal(),
      metadata: _map(json['metadata']),
      beforeValue: _map(json['before_value']),
      afterValue: _map(json['after_value']),
    );
  }
}

class TaskGovernanceCenter {
  final List<TaskGovernanceObject> objects;
  final List<DeletedTaskEntry> trash;
  final List<TaskActionAuditEntry> audit;

  const TaskGovernanceCenter({
    required this.objects,
    required this.trash,
    required this.audit,
  });

  factory TaskGovernanceCenter.fromJson(Map<String, dynamic> json) {
    return TaskGovernanceCenter(
      objects: _maps(json['objects'])
          .map(TaskGovernanceObject.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      trash: _maps(json['trash'])
          .map(DeletedTaskEntry.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      audit: _maps(json['audit'])
          .map(TaskActionAuditEntry.fromJson)
          .toList(growable: false),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.map(_map).toList(growable: false);
}
