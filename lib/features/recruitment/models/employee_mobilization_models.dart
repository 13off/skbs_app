class EmployeeMobilizationCandidate {
  final String applicationId;
  final String companyId;
  final String employeeId;
  final String fullName;
  final String positionTitle;
  final String objectId;
  final String objectName;

  const EmployeeMobilizationCandidate({
    required this.applicationId,
    required this.companyId,
    required this.employeeId,
    required this.fullName,
    required this.positionTitle,
    required this.objectId,
    required this.objectName,
  });

  factory EmployeeMobilizationCandidate.fromMap(Map<String, dynamic> map) {
    final objectValue = map['objects'];
    final object = objectValue is Map
        ? Map<String, dynamic>.from(objectValue)
        : const <String, dynamic>{};
    return EmployeeMobilizationCandidate(
      applicationId: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      positionTitle: map['position_title']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: object['name']?.toString() ?? '',
    );
  }
}

class EmployeeMobilization {
  final String id;
  final String companyId;
  final String applicationId;
  final String employeeId;
  final String objectId;
  final DateTime? plannedStartDate;
  final bool ticketBooked;
  final bool arrivalConfirmed;
  final bool accommodationConfirmed;
  final bool medicalCleared;
  final bool clothingIssued;
  final bool safetyInducted;
  final bool objectAssigned;
  final bool attendanceEnabled;
  final String status;
  final String notes;
  final DateTime? completedAt;

  const EmployeeMobilization({
    required this.id,
    required this.companyId,
    required this.applicationId,
    required this.employeeId,
    required this.objectId,
    required this.plannedStartDate,
    required this.ticketBooked,
    required this.arrivalConfirmed,
    required this.accommodationConfirmed,
    required this.medicalCleared,
    required this.clothingIssued,
    required this.safetyInducted,
    required this.objectAssigned,
    required this.attendanceEnabled,
    required this.status,
    required this.notes,
    required this.completedAt,
  });

  factory EmployeeMobilization.empty(EmployeeMobilizationCandidate candidate) {
    return EmployeeMobilization(
      id: '',
      companyId: candidate.companyId,
      applicationId: candidate.applicationId,
      employeeId: candidate.employeeId,
      objectId: candidate.objectId,
      plannedStartDate: null,
      ticketBooked: false,
      arrivalConfirmed: false,
      accommodationConfirmed: false,
      medicalCleared: false,
      clothingIssued: false,
      safetyInducted: false,
      objectAssigned: false,
      attendanceEnabled: false,
      status: 'draft',
      notes: '',
      completedAt: null,
    );
  }

  factory EmployeeMobilization.fromMap(Map<String, dynamic> map) {
    DateTime? date(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    return EmployeeMobilization(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      plannedStartDate: date(map['planned_start_date']),
      ticketBooked: map['ticket_booked'] == true,
      arrivalConfirmed: map['arrival_confirmed'] == true,
      accommodationConfirmed: map['accommodation_confirmed'] == true,
      medicalCleared: map['medical_cleared'] == true,
      clothingIssued: map['clothing_issued'] == true,
      safetyInducted: map['safety_inducted'] == true,
      objectAssigned: map['object_assigned'] == true,
      attendanceEnabled: map['attendance_enabled'] == true,
      status: map['status']?.toString() ?? 'draft',
      notes: map['notes']?.toString() ?? '',
      completedAt: date(map['completed_at']),
    );
  }

  int get completedSteps => <bool>[
        ticketBooked,
        arrivalConfirmed,
        accommodationConfirmed,
        medicalCleared,
        clothingIssued,
        safetyInducted,
        objectAssigned,
        attendanceEnabled,
      ].where((value) => value).length;

  bool get isCompleted => status == 'completed';

  String get statusTitle => switch (status) {
        'completed' => 'Готов к работе',
        'in_progress' => 'Подготовка',
        _ => 'Не начато',
      };
}

class EmployeeMobilizationEntry {
  final EmployeeMobilizationCandidate candidate;
  final EmployeeMobilization mobilization;

  const EmployeeMobilizationEntry({
    required this.candidate,
    required this.mobilization,
  });
}
