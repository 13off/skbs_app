class DocumentWorkflowAccess {
  final bool canView;
  final bool canManage;
  final bool canCreate;
  final bool canEdit;
  final bool canVerify;
  final bool canManagePackages;
  final bool canViewAudit;
  final bool canViewTemplates;
  final bool canEditTemplates;

  const DocumentWorkflowAccess({
    required this.canView,
    required this.canManage,
    required this.canCreate,
    required this.canEdit,
    required this.canVerify,
    required this.canManagePackages,
    required this.canViewAudit,
    required this.canViewTemplates,
    required this.canEditTemplates,
  });

  static const none = DocumentWorkflowAccess(
    canView: false,
    canManage: false,
    canCreate: false,
    canEdit: false,
    canVerify: false,
    canManagePackages: false,
    canViewAudit: false,
    canViewTemplates: false,
    canEditTemplates: false,
  );

  bool get hasEntry => canView || canManage;

  factory DocumentWorkflowAccess.fromMap(Map<String, dynamic> map) {
    return DocumentWorkflowAccess(
      canView: map['view'] == true,
      canManage: map['manage'] == true,
      canCreate: map['create'] == true,
      canEdit: map['edit'] == true,
      canVerify: map['verify'] == true,
      canManagePackages: map['packages'] == true,
      canViewAudit: map['audit'] == true,
      canViewTemplates: map['templates_view'] == true,
      canEditTemplates: map['templates_edit'] == true,
    );
  }
}

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
      settings: jsonMap(map['settings']),
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

class DocumentPackageTemplateLink {
  final String packageId;
  final String templateId;
  final int sortOrder;
  final bool isRequired;

  const DocumentPackageTemplateLink({
    required this.packageId,
    required this.templateId,
    required this.sortOrder,
    required this.isRequired,
  });

  factory DocumentPackageTemplateLink.fromMap(Map<String, dynamic> map) {
    return DocumentPackageTemplateLink(
      packageId: map['package_id']?.toString() ?? '',
      templateId: map['template_id']?.toString() ?? '',
      sortOrder: intValue(map['sort_order']),
      isRequired: map['is_required'] != false,
    );
  }
}

class DocumentCandidateOption {
  final String id;
  final String fullName;
  final String phone;
  final String objectId;
  final String objectName;
  final String position;
  final String? employeeId;

  const DocumentCandidateOption({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.objectId,
    required this.objectName,
    required this.position,
    required this.employeeId,
  });

  factory DocumentCandidateOption.fromMap(Map<String, dynamic> map) {
    final object = jsonMap(map['objects']);
    return DocumentCandidateOption(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: object['name']?.toString() ?? '',
      position: map['position_title']?.toString() ?? '',
      employeeId: nullableText(map['employee_id']),
    );
  }
}

class DocumentEmployeeOption {
  final String id;
  final String fullName;
  final String phone;
  final String position;
  final String objectId;
  final String objectName;

  const DocumentEmployeeOption({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.position,
    required this.objectId,
    required this.objectName,
  });

  factory DocumentEmployeeOption.fromMap(Map<String, dynamic> map) {
    return DocumentEmployeeOption(
      id: map['id']?.toString() ?? '',
      fullName: map['fio']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      position: map['position']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
    );
  }
}

class DocumentObjectOption {
  final String id;
  final String name;

  const DocumentObjectOption({required this.id, required this.name});

  factory DocumentObjectOption.fromMap(Map<String, dynamic> map) {
    return DocumentObjectOption(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
    );
  }
}

class EmployeeOnboardingRecord {
  final String id;
  final String companyId;
  final String? recruitmentApplicationId;
  final String? employeeId;
  final String? packageId;
  final String? objectId;
  final String status;
  final String currentStep;
  final String onboardingType;
  final String? assignedUserId;
  final DateTime? dueAt;
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> recognizedData;
  final Map<String, dynamic> verificationData;
  final Map<String, dynamic> completionSnapshot;
  final String employeeName;
  final String candidateName;
  final String packageTitle;
  final String objectName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeOnboardingRecord({
    required this.id,
    required this.companyId,
    required this.recruitmentApplicationId,
    required this.employeeId,
    required this.packageId,
    required this.objectId,
    required this.status,
    required this.currentStep,
    required this.onboardingType,
    required this.assignedUserId,
    required this.dueAt,
    required this.conditions,
    required this.recognizedData,
    required this.verificationData,
    required this.completionSnapshot,
    required this.employeeName,
    required this.candidateName,
    required this.packageTitle,
    required this.objectName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isBlocked => status == 'blocked';
  String get personName {
    final employee = employeeName.trim();
    if (employee.isNotEmpty) return employee;
    final candidate = candidateName.trim();
    return candidate.isEmpty ? 'Сотрудник не выбран' : candidate;
  }

  factory EmployeeOnboardingRecord.fromMap(Map<String, dynamic> map) {
    final employee = jsonMap(map['employees']);
    final candidate = jsonMap(map['recruitment_applications']);
    final package = jsonMap(map['document_packages']);
    final object = jsonMap(map['objects']);
    return EmployeeOnboardingRecord(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      recruitmentApplicationId: nullableText(map['recruitment_application_id']),
      employeeId: nullableText(map['employee_id']),
      packageId: nullableText(map['package_id']),
      objectId: nullableText(map['object_id']),
      status: map['status']?.toString() ?? 'draft',
      currentStep: map['current_step']?.toString() ?? 'source_files',
      onboardingType: map['onboarding_type']?.toString() ?? 'custom',
      assignedUserId: nullableText(map['assigned_user_id']),
      dueAt: dateValue(map['due_at']),
      conditions: jsonMap(map['conditions']),
      recognizedData: jsonMap(map['recognized_data']),
      verificationData: jsonMap(map['verification_data']),
      completionSnapshot: jsonMap(map['completion_snapshot']),
      employeeName: employee['fio']?.toString() ?? '',
      candidateName: candidate['full_name']?.toString() ?? '',
      packageTitle: package['title']?.toString() ?? '',
      objectName: object['name']?.toString() ?? '',
      createdAt: dateValue(map['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: dateValue(map['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
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

Map<String, dynamic> jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String? nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? dateValue(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

int intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
