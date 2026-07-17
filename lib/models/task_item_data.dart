class TaskItemData {
  final String? id;
  final String axes;
  final String work;
  final String status;
  final DateTime date;
  final String objectName;
  final String notDoneComment;

  /// null — связь не загружалась и при обновлении её нельзя менять;
  /// пустая строка — пользователь явно выбрал «Не привязано».
  final String? milestoneId;
  final String? checklistItemId;

  const TaskItemData(
    this.axes,
    this.work,
    this.status,
    this.date, {
    this.id,
    this.objectName = 'Мурманск',
    this.notDoneComment = '',
    this.milestoneId,
    this.checklistItemId,
  });

  factory TaskItemData.fromJson(Map<String, dynamic> json) {
    return TaskItemData(
      json['axes'] as String? ?? '',
      json['work'] as String? ?? '',
      json['status'] as String? ?? 'Запланировано',
      DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      id: json['id'] as String?,
      objectName: json['object_name'] as String? ?? 'Мурманск',
      notDoneComment: json['not_done_comment'] as String? ?? '',
      milestoneId: json['milestone_id'] as String?,
      checklistItemId: json['checklist_item_id'] as String?,
    );
  }

  factory TaskItemData.fromSupabase(Map<String, dynamic> json) {
    return TaskItemData(
      json['axes'] as String? ?? '',
      json['work'] as String? ?? '',
      json['status'] as String? ?? 'Запланировано',
      DateTime.tryParse(json['task_date'] as String? ?? '') ?? DateTime.now(),
      id: json['id'] as String?,
      objectName: json['object_name'] as String? ?? 'Мурманск',
      notDoneComment: json['not_done_comment'] as String? ?? '',
      milestoneId: json['milestone_id'] as String?,
      checklistItemId: json['checklist_item_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'axes': axes,
      'work': work,
      'status': status,
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'object_name': objectName,
      'not_done_comment': notDoneComment,
      'milestone_id': milestoneId,
      'checklist_item_id': checklistItemId,
    };
  }

  TaskItemData copyWith({
    String? id,
    String? axes,
    String? work,
    String? status,
    DateTime? date,
    String? objectName,
    String? notDoneComment,
    String? milestoneId,
    String? checklistItemId,
  }) {
    return TaskItemData(
      axes ?? this.axes,
      work ?? this.work,
      status ?? this.status,
      date ?? this.date,
      id: id ?? this.id,
      objectName: objectName ?? this.objectName,
      notDoneComment: notDoneComment ?? this.notDoneComment,
      milestoneId: milestoneId ?? this.milestoneId,
      checklistItemId: checklistItemId ?? this.checklistItemId,
    );
  }
}
