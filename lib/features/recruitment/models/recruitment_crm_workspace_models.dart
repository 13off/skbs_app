import 'recruitment_models.dart';

class RecruitmentResponsibleOption {
  final String userId;
  final String fullName;
  final String role;

  const RecruitmentResponsibleOption({
    required this.userId,
    required this.fullName,
    required this.role,
  });

  factory RecruitmentResponsibleOption.fromMap(Map<String, dynamic> map) {
    return RecruitmentResponsibleOption(
      userId: map['user_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'Пользователь AppСтрой',
      role: map['role']?.toString() ?? 'hr',
    );
  }
}

class RecruitmentCrmComment {
  final String id;
  final String companyId;
  final String applicationId;
  final String body;
  final String createdBy;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecruitmentCrmComment({
    required this.id,
    required this.companyId,
    required this.applicationId,
    required this.body,
    required this.createdBy,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecruitmentCrmComment.fromMap(
    Map<String, dynamic> map, {
    String authorName = 'Пользователь AppСтрой',
  }) {
    final createdAt = _date(map['created_at']);
    return RecruitmentCrmComment(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      authorName: authorName,
      createdAt: createdAt,
      updatedAt: _date(map['updated_at'], fallback: createdAt),
    );
  }
}

const List<String> recruitmentCrmTaskTypes = <String>[
  'call',
  'documents',
  'review',
  'ticket',
  'meeting',
  'message',
  'other',
];

String recruitmentCrmTaskTypeTitle(String value) {
  switch (value) {
    case 'call':
      return 'Позвонить';
    case 'documents':
      return 'Документы';
    case 'review':
      return 'Проверка';
    case 'ticket':
      return 'Билеты';
    case 'meeting':
      return 'Встреча';
    case 'message':
      return 'Сообщение';
    default:
      return 'Другое';
  }
}

const List<String> recruitmentCrmPriorities = <String>[
  'low',
  'normal',
  'high',
  'critical',
];

String recruitmentCrmPriorityTitle(String value) {
  switch (value) {
    case 'low':
      return 'Низкий';
    case 'high':
      return 'Высокий';
    case 'critical':
      return 'Критический';
    default:
      return 'Обычный';
  }
}

class RecruitmentCrmTask {
  final String id;
  final String companyId;
  final String applicationId;
  final String title;
  final String description;
  final String taskType;
  final String priority;
  final DateTime? dueAt;
  final String assignedTo;
  final String assigneeName;
  final String status;
  final DateTime? completedAt;
  final String completedBy;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecruitmentCrmTask({
    required this.id,
    required this.companyId,
    required this.applicationId,
    required this.title,
    required this.description,
    required this.taskType,
    required this.priority,
    required this.dueAt,
    required this.assignedTo,
    required this.assigneeName,
    required this.status,
    required this.completedAt,
    required this.completedBy,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isOverdue =>
      isPending && dueAt != null && dueAt!.isBefore(DateTime.now());
  String get typeTitle => recruitmentCrmTaskTypeTitle(taskType);
  String get priorityTitle => recruitmentCrmPriorityTitle(priority);

  factory RecruitmentCrmTask.fromMap(
    Map<String, dynamic> map, {
    String assigneeName = '',
    String creatorName = '',
  }) {
    final createdAt = _date(map['created_at']);
    return RecruitmentCrmTask(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      taskType: map['task_type']?.toString() ?? 'other',
      priority: map['priority']?.toString() ?? 'normal',
      dueAt: _optionalDate(map['due_at']),
      assignedTo: map['assigned_to']?.toString() ?? '',
      assigneeName: assigneeName,
      status: map['status']?.toString() ?? 'pending',
      completedAt: _optionalDate(map['completed_at']),
      completedBy: map['completed_by']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      creatorName: creatorName,
      createdAt: createdAt,
      updatedAt: _date(map['updated_at'], fallback: createdAt),
    );
  }
}

class RecruitmentCrmActivity {
  final String id;
  final String companyId;
  final String applicationId;
  final String eventType;
  final String title;
  final String body;
  final Map<String, dynamic> metadata;
  final String actorUserId;
  final String actorName;
  final DateTime createdAt;

  const RecruitmentCrmActivity({
    required this.id,
    required this.companyId,
    required this.applicationId,
    required this.eventType,
    required this.title,
    required this.body,
    required this.metadata,
    required this.actorUserId,
    required this.actorName,
    required this.createdAt,
  });

  factory RecruitmentCrmActivity.fromMap(Map<String, dynamic> map) {
    return RecruitmentCrmActivity(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? 'system',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      metadata: _map(map['metadata']),
      actorUserId: map['actor_user_id']?.toString() ?? '',
      actorName: map['actor_name']?.toString() ?? 'Система AppСтрой',
      createdAt: _date(map['created_at']),
    );
  }
}

class RecruitmentCandidateIndicator {
  final String responsibleUserId;
  final String responsibleName;
  final int openTasks;
  final int overdueTasks;
  final DateTime? nextTaskDueAt;
  final String nextTaskTitle;

  const RecruitmentCandidateIndicator({
    this.responsibleUserId = '',
    this.responsibleName = '',
    this.openTasks = 0,
    this.overdueTasks = 0,
    this.nextTaskDueAt,
    this.nextTaskTitle = '',
  });
}

class RecruitmentCrmSavedView {
  final String id;
  final String companyId;
  final String userId;
  final String title;
  final Map<String, dynamic> filters;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecruitmentCrmSavedView({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.title,
    required this.filters,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecruitmentCrmSavedView.fromMap(Map<String, dynamic> map) {
    final createdAt = _date(map['created_at']);
    return RecruitmentCrmSavedView(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      filters: _map(map['filters']),
      isDefault: map['is_default'] == true,
      createdAt: createdAt,
      updatedAt: _date(map['updated_at'], fallback: createdAt),
    );
  }
}

const List<String> recruitmentAutomationActionTypes = <String>[
  'create_task',
  'send_message',
  'create_task_and_message',
];

String recruitmentAutomationActionTitle(String value) {
  switch (value) {
    case 'send_message':
      return 'Отправить сообщение';
    case 'create_task_and_message':
      return 'Создать дело и отправить сообщение';
    default:
      return 'Создать дело';
  }
}

class RecruitmentCrmAutomationRule {
  final String id;
  final String companyId;
  final String triggerStageId;
  final String title;
  final String actionType;
  final String taskTitle;
  final String taskType;
  final String taskPriority;
  final int dueOffsetHours;
  final String messageText;
  final String assignedTo;
  final bool isActive;
  final int sortOrder;

  const RecruitmentCrmAutomationRule({
    required this.id,
    required this.companyId,
    required this.triggerStageId,
    required this.title,
    required this.actionType,
    required this.taskTitle,
    required this.taskType,
    required this.taskPriority,
    required this.dueOffsetHours,
    required this.messageText,
    required this.assignedTo,
    required this.isActive,
    required this.sortOrder,
  });

  String get actionTitle => recruitmentAutomationActionTitle(actionType);

  factory RecruitmentCrmAutomationRule.fromMap(Map<String, dynamic> map) {
    return RecruitmentCrmAutomationRule(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      triggerStageId: map['trigger_stage_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      actionType: map['action_type']?.toString() ?? 'create_task',
      taskTitle: map['task_title']?.toString() ?? '',
      taskType: map['task_type']?.toString() ?? 'other',
      taskPriority: map['task_priority']?.toString() ?? 'normal',
      dueOffsetHours: switch (map['due_offset_hours']) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(map['due_offset_hours']?.toString() ?? '') ?? 24,
      },
      messageText: map['message_text']?.toString() ?? '',
      assignedTo: map['assigned_to']?.toString() ?? '',
      isActive: map['is_active'] != false,
      sortOrder: switch (map['sort_order']) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(map['sort_order']?.toString() ?? '') ?? 100,
      },
    );
  }
}

class RecruitmentCandidateWorkspaceData {
  final List<RecruitmentCrmComment> comments;
  final List<RecruitmentCrmTask> tasks;
  final List<RecruitmentCrmActivity> activities;
  final List<RecruitmentResponsibleOption> responsibles;

  const RecruitmentCandidateWorkspaceData({
    required this.comments,
    required this.tasks,
    required this.activities,
    required this.responsibles,
  });

  static const empty = RecruitmentCandidateWorkspaceData(
    comments: <RecruitmentCrmComment>[],
    tasks: <RecruitmentCrmTask>[],
    activities: <RecruitmentCrmActivity>[],
    responsibles: <RecruitmentResponsibleOption>[],
  );

  List<RecruitmentCrmTask> get pendingTasks =>
      tasks.where((task) => task.isPending).toList()..sort((first, second) {
        final firstDue = first.dueAt ?? DateTime(9999);
        final secondDue = second.dueAt ?? DateTime(9999);
        return firstDue.compareTo(secondDue);
      });
}

class RecruitmentBoardSupportData {
  final List<RecruitmentResponsibleOption> responsibles;
  final Map<String, RecruitmentCandidateIndicator> indicators;
  final List<RecruitmentCrmSavedView> savedViews;

  const RecruitmentBoardSupportData({
    required this.responsibles,
    required this.indicators,
    required this.savedViews,
  });

  static const empty = RecruitmentBoardSupportData(
    responsibles: <RecruitmentResponsibleOption>[],
    indicators: <String, RecruitmentCandidateIndicator>{},
    savedViews: <RecruitmentCrmSavedView>[],
  );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

DateTime _date(dynamic value, {DateTime? fallback}) {
  return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
      fallback ??
      DateTime.now();
}

DateTime? _optionalDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
}
