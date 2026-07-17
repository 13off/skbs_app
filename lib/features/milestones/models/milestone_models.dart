class MilestoneTaskData {
  final String taskId;
  final String work;
  final String axes;
  final String status;
  final DateTime date;
  final int progressPercent;

  const MilestoneTaskData({
    required this.taskId,
    required this.work,
    required this.axes,
    required this.status,
    required this.date,
    this.progressPercent = 0,
  });

  bool get isDone => status == 'Выполнено';
}

class MilestoneChecklistItem {
  final String id;
  final String milestoneId;
  final String title;
  final int weight;
  final String state;
  final bool isCritical;
  final int sortOrder;
  final List<MilestoneTaskData> tasks;

  const MilestoneChecklistItem({
    required this.id,
    required this.milestoneId,
    required this.title,
    required this.weight,
    required this.state,
    required this.isCritical,
    required this.sortOrder,
    this.tasks = const <MilestoneTaskData>[],
  });

  int get doneTaskCount => tasks.where((task) => task.isDone).length;

  int get accumulatedTaskProgress {
    final total = tasks
        .where((task) => task.isDone)
        .fold<int>(0, (sum, task) => sum + task.progressPercent);
    return total.clamp(0, 100).toInt();
  }

  int get progressPercent {
    if (state == 'blocked') return 0;
    if (state == 'done') return 100;

    final accumulated = accumulatedTaskProgress;
    if (accumulated > 0) return accumulated;

    // Совместимость со старыми задачами без дневного процента.
    if (tasks.isNotEmpty && doneTaskCount == tasks.length) return 100;
    return 0;
  }

  int get remainingProgressPercent =>
      (100 - progressPercent).clamp(0, 100).toInt();
  double get completionFraction => progressPercent / 100;
  bool get isEffectivelyDone => progressPercent >= 100;
  bool get isBlocked => state == 'blocked';

  String get stateTitle {
    if (isBlocked) return 'Заблокировано';
    if (isEffectivelyDone) return 'Готово · 100%';
    if (progressPercent > 0) return 'В работе · $progressPercent%';
    return 'Не начато · 0%';
  }

  MilestoneChecklistItem copyWith({
    String? state,
    List<MilestoneTaskData>? tasks,
  }) {
    return MilestoneChecklistItem(
      id: id,
      milestoneId: milestoneId,
      title: title,
      weight: weight,
      state: state ?? this.state,
      isCritical: isCritical,
      sortOrder: sortOrder,
      tasks: tasks ?? this.tasks,
    );
  }
}

class ProjectMilestone {
  final String id;
  final String objectName;
  final String title;
  final String location;
  final DateTime targetDate;
  final String status;
  final String notes;
  final List<MilestoneChecklistItem> items;

  const ProjectMilestone({
    required this.id,
    required this.objectName,
    required this.title,
    required this.location,
    required this.targetDate,
    required this.status,
    required this.notes,
    this.items = const <MilestoneChecklistItem>[],
  });

  int get totalWeight => items.fold<int>(0, (sum, item) => sum + item.weight);

  double get progress {
    final total = totalWeight;
    if (total <= 0) return 0;
    final completed = items.fold<double>(
      0,
      (sum, item) => sum + item.weight * item.completionFraction,
    );
    return (completed / total).clamp(0, 1).toDouble();
  }

  int get progressPercent => (progress * 100).round();
  int get doneItems => items.where((item) => item.isEffectivelyDone).length;
  int get linkedTaskCount =>
      items.fold<int>(0, (sum, item) => sum + item.tasks.length);
  int get doneTaskCount =>
      items.fold<int>(0, (sum, item) => sum + item.doneTaskCount);

  List<MilestoneChecklistItem> get blockingItems => items
      .where((item) => item.isCritical && !item.isEffectivelyDone)
      .toList();

  bool get isReady => items.isNotEmpty && blockingItems.isEmpty && progress >= 1;
  bool get isCompleted => status == 'completed' || isReady;

  String get statusTitle {
    if (isCompleted) return 'Выполнено';
    switch (status) {
      case 'preparing':
        return 'Подготовка';
      case 'ready':
        return 'Готово к выполнению';
      case 'postponed':
        return 'Перенесено';
      default:
        return 'Запланировано';
    }
  }

  ProjectMilestone copyWith({
    List<MilestoneChecklistItem>? items,
    String? status,
  }) {
    return ProjectMilestone(
      id: id,
      objectName: objectName,
      title: title,
      location: location,
      targetDate: targetDate,
      status: status ?? this.status,
      notes: notes,
      items: items ?? this.items,
    );
  }
}

class MilestoneChecklistDraft {
  final String title;
  final int weight;
  final bool isCritical;

  const MilestoneChecklistDraft({
    required this.title,
    required this.weight,
    required this.isCritical,
  });
}
