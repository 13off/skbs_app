class TaskPolicy {
  final String id;
  final String companyId;
  final String objectId;
  final bool requireBeforePhoto;
  final int minBeforePhotos;
  final bool requireAfterPhotoOnComplete;
  final int minAfterPhotos;
  final bool requireNotDoneComment;
  final bool foremanCanCreateAnyDate;
  final bool foremanCanEditPastTasks;
  final int? editWindowDays;
  final bool foremanCanEditDate;
  final bool foremanCanEditAxesWork;
  final bool foremanCanEditAssignees;
  final bool foremanCanEditStatus;
  final bool foremanCanDeleteBeforePhotos;
  final bool foremanCanDeleteAfterPhotos;
  final bool foremanCanDeleteTask;
  final DateTime? updatedAt;
  final String updatedBy;

  const TaskPolicy({
    this.id = '',
    this.companyId = '',
    this.objectId = '',
    this.requireBeforePhoto = true,
    this.minBeforePhotos = 1,
    this.requireAfterPhotoOnComplete = true,
    this.minAfterPhotos = 1,
    this.requireNotDoneComment = true,
    this.foremanCanCreateAnyDate = false,
    this.foremanCanEditPastTasks = false,
    this.editWindowDays = 0,
    this.foremanCanEditDate = true,
    this.foremanCanEditAxesWork = true,
    this.foremanCanEditAssignees = true,
    this.foremanCanEditStatus = true,
    this.foremanCanDeleteBeforePhotos = true,
    this.foremanCanDeleteAfterPhotos = true,
    this.foremanCanDeleteTask = false,
    this.updatedAt,
    this.updatedBy = '',
  });

  static const defaults = TaskPolicy();

  factory TaskPolicy.fromJson(Map<String, dynamic> json) {
    int integer(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool boolean(String key, bool fallback) {
      final value = json[key];
      if (value is bool) return value;
      if (value == null) return fallback;
      return value.toString().toLowerCase() == 'true';
    }

    final windowValue = json['edit_window_days'];
    return TaskPolicy(
      id: json['id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? '',
      objectId: json['object_id']?.toString() ?? '',
      requireBeforePhoto: boolean('require_before_photo', true),
      minBeforePhotos: integer('min_before_photos', 1).clamp(0, 20).toInt(),
      requireAfterPhotoOnComplete: boolean(
        'require_after_photo_on_complete',
        true,
      ),
      minAfterPhotos: integer('min_after_photos', 1).clamp(0, 20).toInt(),
      requireNotDoneComment: boolean('require_not_done_comment', true),
      foremanCanCreateAnyDate: boolean(
        'foreman_can_create_any_date',
        false,
      ),
      foremanCanEditPastTasks: boolean(
        'foreman_can_edit_past_tasks',
        false,
      ),
      editWindowDays: windowValue == null
          ? null
          : int.tryParse(windowValue.toString())?.clamp(0, 3650).toInt(),
      foremanCanEditDate: boolean('foreman_can_edit_date', true),
      foremanCanEditAxesWork: boolean('foreman_can_edit_axes_work', true),
      foremanCanEditAssignees: boolean(
        'foreman_can_edit_assignees',
        true,
      ),
      foremanCanEditStatus: boolean('foreman_can_edit_status', true),
      foremanCanDeleteBeforePhotos: boolean(
        'foreman_can_delete_before_photos',
        true,
      ),
      foremanCanDeleteAfterPhotos: boolean(
        'foreman_can_delete_after_photos',
        true,
      ),
      foremanCanDeleteTask: boolean('foreman_can_delete_task', false),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '')
          ?.toLocal(),
      updatedBy: json['updated_by']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'require_before_photo': requireBeforePhoto,
      'min_before_photos': minBeforePhotos,
      'require_after_photo_on_complete': requireAfterPhotoOnComplete,
      'min_after_photos': minAfterPhotos,
      'require_not_done_comment': requireNotDoneComment,
      'foreman_can_create_any_date': foremanCanCreateAnyDate,
      'foreman_can_edit_past_tasks': foremanCanEditPastTasks,
      'edit_window_days': editWindowDays,
      'foreman_can_edit_date': foremanCanEditDate,
      'foreman_can_edit_axes_work': foremanCanEditAxesWork,
      'foreman_can_edit_assignees': foremanCanEditAssignees,
      'foreman_can_edit_status': foremanCanEditStatus,
      'foreman_can_delete_before_photos': foremanCanDeleteBeforePhotos,
      'foreman_can_delete_after_photos': foremanCanDeleteAfterPhotos,
      'foreman_can_delete_task': foremanCanDeleteTask,
    };
  }

  TaskPolicy copyWith({
    String? id,
    String? companyId,
    String? objectId,
    bool? requireBeforePhoto,
    int? minBeforePhotos,
    bool? requireAfterPhotoOnComplete,
    int? minAfterPhotos,
    bool? requireNotDoneComment,
    bool? foremanCanCreateAnyDate,
    bool? foremanCanEditPastTasks,
    Object? editWindowDays = _notProvided,
    bool? foremanCanEditDate,
    bool? foremanCanEditAxesWork,
    bool? foremanCanEditAssignees,
    bool? foremanCanEditStatus,
    bool? foremanCanDeleteBeforePhotos,
    bool? foremanCanDeleteAfterPhotos,
    bool? foremanCanDeleteTask,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return TaskPolicy(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      objectId: objectId ?? this.objectId,
      requireBeforePhoto: requireBeforePhoto ?? this.requireBeforePhoto,
      minBeforePhotos: minBeforePhotos ?? this.minBeforePhotos,
      requireAfterPhotoOnComplete:
          requireAfterPhotoOnComplete ?? this.requireAfterPhotoOnComplete,
      minAfterPhotos: minAfterPhotos ?? this.minAfterPhotos,
      requireNotDoneComment:
          requireNotDoneComment ?? this.requireNotDoneComment,
      foremanCanCreateAnyDate:
          foremanCanCreateAnyDate ?? this.foremanCanCreateAnyDate,
      foremanCanEditPastTasks:
          foremanCanEditPastTasks ?? this.foremanCanEditPastTasks,
      editWindowDays: identical(editWindowDays, _notProvided)
          ? this.editWindowDays
          : editWindowDays as int?,
      foremanCanEditDate: foremanCanEditDate ?? this.foremanCanEditDate,
      foremanCanEditAxesWork:
          foremanCanEditAxesWork ?? this.foremanCanEditAxesWork,
      foremanCanEditAssignees:
          foremanCanEditAssignees ?? this.foremanCanEditAssignees,
      foremanCanEditStatus:
          foremanCanEditStatus ?? this.foremanCanEditStatus,
      foremanCanDeleteBeforePhotos:
          foremanCanDeleteBeforePhotos ?? this.foremanCanDeleteBeforePhotos,
      foremanCanDeleteAfterPhotos:
          foremanCanDeleteAfterPhotos ?? this.foremanCanDeleteAfterPhotos,
      foremanCanDeleteTask:
          foremanCanDeleteTask ?? this.foremanCanDeleteTask,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

const Object _notProvided = Object();

class DeveloperObjectPolicy {
  final String id;
  final String name;
  final bool hasOverride;
  final TaskPolicy policy;

  const DeveloperObjectPolicy({
    required this.id,
    required this.name,
    required this.hasOverride,
    required this.policy,
  });

  factory DeveloperObjectPolicy.fromJson(Map<String, dynamic> json) {
    return DeveloperObjectPolicy(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      hasOverride: json['has_override'] == true,
      policy: TaskPolicy.fromJson(_map(json['policy'])),
    );
  }
}

class DeveloperAuditEntry {
  final int id;
  final String objectId;
  final String objectName;
  final String action;
  final DateTime? changedAt;
  final String changedByName;

  const DeveloperAuditEntry({
    required this.id,
    required this.objectId,
    required this.objectName,
    required this.action,
    required this.changedAt,
    required this.changedByName,
  });

  factory DeveloperAuditEntry.fromJson(Map<String, dynamic> json) {
    return DeveloperAuditEntry(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      objectId: json['object_id']?.toString() ?? '',
      objectName: json['object_name']?.toString() ?? '',
      action: json['action']?.toString() ?? 'update',
      changedAt: DateTime.tryParse(json['changed_at']?.toString() ?? '')
          ?.toLocal(),
      changedByName: json['changed_by_name']?.toString() ?? '',
    );
  }
}

class DeveloperTaskPolicyCenter {
  final TaskPolicy companyPolicy;
  final List<DeveloperObjectPolicy> objects;
  final List<DeveloperAuditEntry> audit;

  const DeveloperTaskPolicyCenter({
    required this.companyPolicy,
    required this.objects,
    required this.audit,
  });

  factory DeveloperTaskPolicyCenter.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(dynamic value) {
      if (value is! List) return const <Map<String, dynamic>>[];
      return value.map(_map).toList();
    }

    return DeveloperTaskPolicyCenter(
      companyPolicy: TaskPolicy.fromJson(_map(json['company_policy'])),
      objects: maps(json['objects'])
          .map(DeveloperObjectPolicy.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(),
      audit: maps(json['audit']).map(DeveloperAuditEntry.fromJson).toList(),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}
