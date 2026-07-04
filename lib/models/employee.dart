class Employee {
  final String? id;
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
    this.phone = '',
    this.objectName = 'Мурманск',
    this.dailyRate = 6000,
    this.isActive = true,
    this.comment = '',
  });

  factory Employee.fromSupabase(Map<String, dynamic> json) {
    return Employee(
      json['fio'] as String? ?? '',
      json['position'] as String? ?? '',
      'не отмечен',
      id: json['id'] as String?,
      phone: json['phone'] as String? ?? '',
      objectName: json['object_name'] as String? ?? 'Мурманск',
      dailyRate: json['daily_rate'] as int? ?? 6000,
      isActive: json['is_active'] as bool? ?? true,
      comment: json['comment'] as String? ?? '',
    );
  }
}
