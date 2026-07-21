class CandidateOnboardingCandidate {
  final String id;
  final String companyId;
  final String employeeId;
  final String fullName;
  final String phone;
  final String citizenship;
  final String positionTitle;
  final String objectName;
  final String status;
  final DateTime? readyDate;
  final bool consentPersonalData;
  final bool isTestRecord;

  const CandidateOnboardingCandidate({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.fullName,
    required this.phone,
    required this.citizenship,
    required this.positionTitle,
    required this.objectName,
    required this.status,
    required this.readyDate,
    required this.consentPersonalData,
    this.isTestRecord = false,
  });

  factory CandidateOnboardingCandidate.fromMap(Map<String, dynamic> map) {
    final objectValue = map['objects'];
    final object = objectValue is Map
        ? Map<String, dynamic>.from(objectValue)
        : const <String, dynamic>{};
    final readyText = map['ready_date']?.toString().trim() ?? '';
    return CandidateOnboardingCandidate(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      citizenship: map['citizenship']?.toString() ?? '',
      positionTitle: map['position_title']?.toString() ?? '',
      objectName: object['name']?.toString() ?? '',
      status: map['status']?.toString() ?? 'new',
      readyDate: readyText.isEmpty ? null : DateTime.tryParse(readyText)?.toLocal(),
      consentPersonalData: map['consent_personal_data'] == true,
      isTestRecord: map['is_test_record'] == true,
    );
  }

  bool get isLinkedToEmployee => employeeId.trim().isNotEmpty;
  bool get isHired => status == 'hired';
}
