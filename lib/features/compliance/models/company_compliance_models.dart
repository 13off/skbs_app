class CompanyEmployerProfile {
  final String companyId;
  final String legalName;
  final String shortName;
  final String legalAddress;
  final String actualAddress;
  final String inn;
  final String kpp;
  final String ogrn;
  final String bankName;
  final String bankAccount;
  final String bankBik;
  final String bankCorrAccount;
  final String representativeName;
  final String representativePosition;
  final String representativeBasis;
  final String contractCity;
  final String workSchedule;
  final String salaryTermsTemplate;
  final String retentionPolicy;
  final bool legalDocumentsApproved;
  final String approvedByName;
  final DateTime? approvedAt;

  const CompanyEmployerProfile({
    required this.companyId,
    this.legalName = '',
    this.shortName = '',
    this.legalAddress = '',
    this.actualAddress = '',
    this.inn = '',
    this.kpp = '',
    this.ogrn = '',
    this.bankName = '',
    this.bankAccount = '',
    this.bankBik = '',
    this.bankCorrAccount = '',
    this.representativeName = '',
    this.representativePosition = '',
    this.representativeBasis = '',
    this.contractCity = '',
    this.workSchedule = '',
    this.salaryTermsTemplate = '',
    this.retentionPolicy = '',
    this.legalDocumentsApproved = false,
    this.approvedByName = '',
    this.approvedAt,
  });

  factory CompanyEmployerProfile.empty(String companyId) =>
      CompanyEmployerProfile(companyId: companyId);

  factory CompanyEmployerProfile.fromMap(Map<String, dynamic> map) {
    return CompanyEmployerProfile(
      companyId: map['company_id']?.toString() ?? '',
      legalName: map['legal_name']?.toString() ?? '',
      shortName: map['short_name']?.toString() ?? '',
      legalAddress: map['legal_address']?.toString() ?? '',
      actualAddress: map['actual_address']?.toString() ?? '',
      inn: map['inn']?.toString() ?? '',
      kpp: map['kpp']?.toString() ?? '',
      ogrn: map['ogrn']?.toString() ?? '',
      bankName: map['bank_name']?.toString() ?? '',
      bankAccount: map['bank_account']?.toString() ?? '',
      bankBik: map['bank_bik']?.toString() ?? '',
      bankCorrAccount: map['bank_corr_account']?.toString() ?? '',
      representativeName: map['representative_name']?.toString() ?? '',
      representativePosition: map['representative_position']?.toString() ?? '',
      representativeBasis: map['representative_basis']?.toString() ?? '',
      contractCity: map['contract_city']?.toString() ?? '',
      workSchedule: map['work_schedule']?.toString() ?? '',
      salaryTermsTemplate: map['salary_terms_template']?.toString() ?? '',
      retentionPolicy: map['retention_policy']?.toString() ?? '',
      legalDocumentsApproved: map['legal_documents_approved'] == true,
      approvedByName: map['approved_by_name']?.toString() ?? '',
      approvedAt: DateTime.tryParse(map['approved_at']?.toString() ?? '')?.toLocal(),
    );
  }

  bool get hasRequiredEmployerDetails =>
      legalName.trim().isNotEmpty &&
      legalAddress.trim().isNotEmpty &&
      inn.trim().isNotEmpty &&
      kpp.trim().isNotEmpty &&
      ogrn.trim().isNotEmpty &&
      representativeName.trim().isNotEmpty &&
      representativePosition.trim().isNotEmpty &&
      representativeBasis.trim().isNotEmpty &&
      contractCity.trim().isNotEmpty &&
      workSchedule.trim().isNotEmpty &&
      retentionPolicy.trim().isNotEmpty;

  String get employerDetails => <String>[
        legalAddress,
        if (actualAddress.trim().isNotEmpty) 'Фактический адрес: $actualAddress',
        'ИНН $inn',
        'КПП $kpp',
        'ОГРН $ogrn',
        if (bankName.trim().isNotEmpty) bankName,
        if (bankAccount.trim().isNotEmpty) 'р/с $bankAccount',
        if (bankBik.trim().isNotEmpty) 'БИК $bankBik',
        if (bankCorrAccount.trim().isNotEmpty) 'к/с $bankCorrAccount',
      ].where((item) => item.trim().isNotEmpty).join('\n');
}

class CompanyPersonalDataGate {
  final String companyId;
  final bool realDocumentsEnabled;
  final bool russianStorageLocationConfirmed;
  final bool dataControllerDetailsApproved;
  final bool personalDataConsentApproved;
  final bool retentionAndDeletionPolicyApproved;
  final bool downloadAuditLogVerified;
  final bool backupAndRestoreTested;
  final bool accessOffboardingTested;
  final bool incidentResponseOwnerAssigned;
  final String storageRegion;
  final int retentionDays;
  final String deletionPolicy;
  final String incidentOwner;
  final String approvedByName;
  final DateTime? approvedAt;

  const CompanyPersonalDataGate({
    required this.companyId,
    this.realDocumentsEnabled = false,
    this.russianStorageLocationConfirmed = false,
    this.dataControllerDetailsApproved = false,
    this.personalDataConsentApproved = false,
    this.retentionAndDeletionPolicyApproved = false,
    this.downloadAuditLogVerified = false,
    this.backupAndRestoreTested = false,
    this.accessOffboardingTested = false,
    this.incidentResponseOwnerAssigned = false,
    this.storageRegion = '',
    this.retentionDays = 0,
    this.deletionPolicy = '',
    this.incidentOwner = '',
    this.approvedByName = '',
    this.approvedAt,
  });

  factory CompanyPersonalDataGate.empty(String companyId) =>
      CompanyPersonalDataGate(companyId: companyId);

  factory CompanyPersonalDataGate.fromMap(Map<String, dynamic> map) {
    return CompanyPersonalDataGate(
      companyId: map['company_id']?.toString() ?? '',
      realDocumentsEnabled: map['real_documents_enabled'] == true,
      russianStorageLocationConfirmed:
          map['russian_storage_location_confirmed'] == true,
      dataControllerDetailsApproved:
          map['data_controller_details_approved'] == true,
      personalDataConsentApproved:
          map['personal_data_consent_approved'] == true,
      retentionAndDeletionPolicyApproved:
          map['retention_and_deletion_policy_approved'] == true,
      downloadAuditLogVerified: map['download_audit_log_verified'] == true,
      backupAndRestoreTested: map['backup_and_restore_tested'] == true,
      accessOffboardingTested: map['access_offboarding_tested'] == true,
      incidentResponseOwnerAssigned:
          map['incident_response_owner_assigned'] == true,
      storageRegion: map['storage_region']?.toString() ?? '',
      retentionDays: (map['retention_days'] as num?)?.toInt() ?? 0,
      deletionPolicy: map['deletion_policy']?.toString() ?? '',
      incidentOwner: map['incident_owner']?.toString() ?? '',
      approvedByName: map['approved_by_name']?.toString() ?? '',
      approvedAt: DateTime.tryParse(map['approved_at']?.toString() ?? '')?.toLocal(),
    );
  }

  bool get allEvidenceComplete =>
      russianStorageLocationConfirmed &&
      dataControllerDetailsApproved &&
      personalDataConsentApproved &&
      retentionAndDeletionPolicyApproved &&
      downloadAuditLogVerified &&
      backupAndRestoreTested &&
      accessOffboardingTested &&
      incidentResponseOwnerAssigned &&
      storageRegion.trim().isNotEmpty &&
      retentionDays > 0 &&
      deletionPolicy.trim().isNotEmpty &&
      incidentOwner.trim().isNotEmpty &&
      approvedByName.trim().isNotEmpty &&
      approvedAt != null;

  int get completedEvidenceCount => <bool>[
        russianStorageLocationConfirmed,
        dataControllerDetailsApproved,
        personalDataConsentApproved,
        retentionAndDeletionPolicyApproved,
        downloadAuditLogVerified,
        backupAndRestoreTested,
        accessOffboardingTested,
        incidentResponseOwnerAssigned,
      ].where((value) => value).length;
}

class CompanyComplianceSnapshot {
  final CompanyEmployerProfile employer;
  final CompanyPersonalDataGate gate;

  const CompanyComplianceSnapshot({
    required this.employer,
    required this.gate,
  });

  bool get realDocumentsAllowed =>
      gate.realDocumentsEnabled &&
      gate.allEvidenceComplete &&
      employer.legalDocumentsApproved &&
      employer.hasRequiredEmployerDetails;
}
