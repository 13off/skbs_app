class DocumentToolInstallation {
  final String companyId;
  final bool isEnabled;
  final Map<String, dynamic> settings;

  const DocumentToolInstallation({
    required this.companyId,
    required this.isEnabled,
    required this.settings,
  });

  factory DocumentToolInstallation.fromMap(Map<String, dynamic> map) {
    return DocumentToolInstallation(
      companyId: map['company_id']?.toString() ?? '',
      isEnabled: map['is_enabled'] == true,
      settings: _jsonMap(map['settings']),
    );
  }
}

class DocumentPackageRecord {
  final String id;
  final String companyId;
  final String code;
  final String title;
  final String description;
  final String onboardingType;
  final bool isActive;

  const DocumentPackageRecord({
    required this.id,
    required this.companyId,
    required this.code,
    required this.title,
    required this.description,
    required this.onboardingType,
    required this.isActive,
  });

  factory DocumentPackageRecord.fromMap(Map<String, dynamic> map) {
    return DocumentPackageRecord(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      onboardingType: map['onboarding_type']?.toString() ?? 'custom',
      isActive: map['is_active'] != false,
    );
  }
}

class EmployeeOnboardingRecord {
  final String id;
  final String companyId;
  final String? employeeId;
  final String? packageId;
  final String status;
  final String currentStep;
  final String onboardingType;
  final String? assignedUserId;
  final DateTime? dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeOnboardingRecord({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.packageId,
    required this.status,
    required this.currentStep,
    required this.onboardingType,
    required this.assignedUserId,
    required this.dueAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isBlocked => status == 'blocked';

  factory EmployeeOnboardingRecord.fromMap(Map<String, dynamic> map) {
    return EmployeeOnboardingRecord(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      employeeId: _nullableText(map['employee_id']),
      packageId: _nullableText(map['package_id']),
      status: map['status']?.toString() ?? 'draft',
      currentStep: map['current_step']?.toString() ?? 'source_files',
      onboardingType: map['onboarding_type']?.toString() ?? 'custom',
      assignedUserId: _nullableText(map['assigned_user_id']),
      dueAt: _date(map['due_at']),
      createdAt: _date(map['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _date(map['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

abstract final class DocumentOnboardingSteps {
  static const sourceFiles = 'source_files';
  static const sourceCompleteness = 'source_completeness';
  static const recognition = 'recognition';
  static const hrVerification = 'hr_verification';
  static const employeeCard = 'employee_card';
  static const packageAndConditions = 'package_and_conditions';
  static const generation = 'generation';
  static const printing = 'printing';
  static const signing = 'signing';
  static const signedDocuments = 'signed_documents';
  static const finalScans = 'final_scans';
  static const archiveVerification = 'archive_verification';
  static const completion = 'completion';

  static const ordered = <String>[
    sourceFiles,
    sourceCompleteness,
    recognition,
    hrVerification,
    employeeCard,
    packageAndConditions,
    generation,
    printing,
    signing,
    signedDocuments,
    finalScans,
    archiveVerification,
    completion,
  ];
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
