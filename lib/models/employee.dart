class Employee {
  final String? id;
  final String? personId;
  final String? objectId;
  final String name;
  final String position;
  final String status;
  final String phone;
  final String objectName;
  final int monthlySalary;
  final bool isActive;
  final String comment;

  const Employee(
    this.name,
    this.position,
    this.status, {
    this.id,
    this.personId,
    this.objectId,
    this.phone = '',
    this.objectName = 'Мурманск',
    int? monthlySalary,
    @Deprecated('Use monthlySalary') int? dailyRate,
    this.isActive = true,
    this.comment = '',
  }) : monthlySalary = monthlySalary ?? dailyRate ?? 0;

  /// Transitional alias for code that has not been migrated yet.
  /// The value is a fixed monthly salary and must never be multiplied by shifts.
  @Deprecated('Use monthlySalary')
  int get dailyRate => monthlySalary;

  String get positionTitle {
    final cleanPosition = position.trim();
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return cleanPosition;

    final contactSuffix = ' • $cleanPhone';
    if (!cleanPosition.endsWith(contactSuffix)) return cleanPosition;

    return cleanPosition
        .substring(0, cleanPosition.length - contactSuffix.length)
        .trim();
  }

  String get positionWithContact => <String>[
    positionTitle,
    if (phone.trim().isNotEmpty) phone.trim(),
  ].where((value) => value.isNotEmpty).join(' • ');

  factory Employee.fromSupabase(Map<String, dynamic> json) {
    final phone = json['phone'] as String? ?? '';
    final position = json['position'] as String? ?? '';
    final positionWithContact = <String>[
      position.trim(),
      if (phone.trim().isNotEmpty) phone.trim(),
    ].where((value) => value.isNotEmpty).join(' • ');
    final monthlySalary =
        (json['monthly_salary'] as num?)?.round() ??
        (json['daily_rate'] as num?)?.round() ??
        0;

    return Employee(
      json['fio'] as String? ?? '',
      positionWithContact,
      'не отмечен',
      id: json['id'] as String?,
      personId: json['person_id'] as String?,
      objectId: json['object_id'] as String?,
      phone: phone.trim(),
      objectName: json['object_name'] as String? ?? 'Мурманск',
      monthlySalary: monthlySalary,
      isActive: json['is_active'] as bool? ?? true,
      comment: json['comment'] as String? ?? '',
    );
  }
}
