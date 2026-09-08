class EstimatorManualVolume {
  final String id;
  final String objectName;
  final String work;
  final String unit;
  final double quantity;
  final DateTime workDate;
  final String reasonCode;
  final String reasonComment;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? voidedAt;
  final String voidedByName;
  final String voidReason;

  const EstimatorManualVolume({
    required this.id,
    required this.objectName,
    required this.work,
    required this.unit,
    required this.quantity,
    required this.workDate,
    required this.reasonCode,
    required this.reasonComment,
    required this.createdByName,
    required this.createdAt,
    required this.voidedAt,
    required this.voidedByName,
    required this.voidReason,
  });

  bool get isVoided => voidedAt != null;

  String get reasonTitle {
    switch (reasonCode) {
      case 'unplanned_work':
        return 'Дополнительная работа';
      case 'task_missing':
        return 'Работа без задачи';
      case 'correction':
        return 'Корректировка объёма';
      case 'carryover':
        return 'Перенос из другого периода';
      default:
        return 'Другое';
    }
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _date(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
  }

  static DateTime? _optionalDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
  }

  factory EstimatorManualVolume.fromMap(Map<String, dynamic> map) {
    return EstimatorManualVolume(
      id: map['id']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      work: map['work']?.toString() ?? '',
      unit: map['unit']?.toString() ?? '',
      quantity: _number(map['quantity']),
      workDate: _date(map['work_date']),
      reasonCode: map['reason_code']?.toString() ?? 'other',
      reasonComment: map['reason_comment']?.toString() ?? '',
      createdByName: map['created_by_name']?.toString() ?? '',
      createdAt: _date(map['created_at']),
      voidedAt: _optionalDate(map['voided_at']),
      voidedByName: map['voided_by_name']?.toString() ?? '',
      voidReason: map['void_reason']?.toString() ?? '',
    );
  }
}
