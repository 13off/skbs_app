class Employee {
  final String? id;
  final String? personId;
  final String? objectId;
  final String name;
  final String position;
  final String status;
  final String phone;
  final String objectName;
  final int dailyRate;
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
    this.dailyRate = 6000,
    this.isActive = true,
    this.comment = '',
  });

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

    return Employee(
      json['fio'] as String? ?? '',
      positionWithContact,
      'не отмечен',
      id: json['id'] as String?,
      personId: json['person_id'] as String?,
      objectId: json['object_id'] as String?,
      phone: phone.trim(),
      objectName: json['object_name'] as String? ?? 'Мурманск',
      dailyRate: json['daily_rate'] as int? ?? 6000,
      isActive: json['is_active'] as bool? ?? true,
      comment: json['comment'] as String? ?? '',
    );
  }
}
