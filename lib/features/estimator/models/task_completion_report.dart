class TaskCompletionReport {
  final String id;
  final String taskId;
  final double? reportedQuantity;
  final String unit;
  final String workLocation;
  final String completionComment;
  final String reviewStatus;
  final double? approvedQuantity;
  final String reviewComment;
  final String submittedByName;
  final DateTime submittedAt;
  final String reviewedByName;
  final DateTime? reviewedAt;
  final DateTime taskDate;
  final String objectName;
  final String axes;
  final String work;

  const TaskCompletionReport({
    required this.id,
    required this.taskId,
    required this.reportedQuantity,
    required this.unit,
    required this.workLocation,
    required this.completionComment,
    required this.reviewStatus,
    required this.approvedQuantity,
    required this.reviewComment,
    required this.submittedByName,
    required this.submittedAt,
    required this.reviewedByName,
    required this.reviewedAt,
    this.taskDate = const _FallbackDate(),
    this.objectName = '',
    this.axes = '',
    this.work = '',
  });

  bool get isPending => reviewStatus == 'pending';
  bool get isApproved => reviewStatus == 'approved';
  bool get isReturned => reviewStatus == 'returned';
  bool get hasVolume => reportedQuantity != null;

  String get statusTitle {
    switch (reviewStatus) {
      case 'approved':
        return 'Подтверждено';
      case 'returned':
        return 'Возвращено мастеру';
      default:
        return 'На проверке';
    }
  }

  String get reportedVolumeTitle {
    final quantity = reportedQuantity;
    if (quantity == null) return 'Без объёма';
    return '${formatQuantity(quantity)}${unit.isEmpty ? '' : ' $unit'}';
  }

  String get approvedVolumeTitle {
    final quantity = approvedQuantity;
    if (quantity == null) return reportedVolumeTitle;
    return '${formatQuantity(quantity)}${unit.isEmpty ? '' : ' $unit'}';
  }

  static String formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    var text = value.toStringAsFixed(3);
    while (text.contains('.') && text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text.replaceAll('.', ',');
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime _date(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
  }

  static DateTime? _optionalDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
  }

  factory TaskCompletionReport.fromMap(Map<String, dynamic> map) {
    final rawTask = map['tasks'];
    final task = rawTask is Map
        ? Map<String, dynamic>.from(rawTask)
        : const <String, dynamic>{};
    return TaskCompletionReport(
      id: map['id']?.toString() ?? '',
      taskId: map['task_id']?.toString() ?? '',
      reportedQuantity: _number(map['reported_quantity']),
      unit: map['unit']?.toString() ?? '',
      workLocation: map['work_location']?.toString() ?? '',
      completionComment: map['completion_comment']?.toString() ?? '',
      reviewStatus: map['review_status']?.toString() ?? 'pending',
      approvedQuantity: _number(map['approved_quantity']),
      reviewComment: map['review_comment']?.toString() ?? '',
      submittedByName: map['submitted_by_name']?.toString() ?? '',
      submittedAt: _date(map['submitted_at']),
      reviewedByName: map['reviewed_by_name']?.toString() ?? '',
      reviewedAt: _optionalDate(map['reviewed_at']),
      taskDate: task.isEmpty ? DateTime.now() : _date(task['task_date']),
      objectName: task['object_name']?.toString() ?? '',
      axes: task['axes']?.toString() ?? '',
      work: task['work']?.toString() ?? '',
    );
  }
}

class _FallbackDate implements DateTime {
  const _FallbackDate();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.fromMillisecondsSinceEpoch(0).noSuchMethod(invocation);
}
