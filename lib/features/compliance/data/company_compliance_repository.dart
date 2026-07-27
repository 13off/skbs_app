import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company_compliance_models.dart';

abstract final class CompanyComplianceRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static Future<CompanyComplianceSnapshot> fetchSnapshot(String companyId) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) {
      throw StateError('Активная компания не выбрана');
    }
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _client
          .from('company_employer_profiles')
          .select()
          .eq('company_id', cleanCompanyId)
          .maybeSingle(),
      _client
          .from('company_personal_data_gates')
          .select()
          .eq('company_id', cleanCompanyId)
          .maybeSingle(),
    ]);
    final employerRow = results[0];
    final gateRow = results[1];
    return CompanyComplianceSnapshot(
      employer: employerRow == null
          ? CompanyEmployerProfile.empty(cleanCompanyId)
          : CompanyEmployerProfile.fromMap(_map(employerRow)),
      gate: gateRow == null
          ? CompanyPersonalDataGate.empty(cleanCompanyId)
          : CompanyPersonalDataGate.fromMap(_map(gateRow)),
    );
  }

  static Future<CompanyEmployerProfile> saveEmployerProfile({
    required String companyId,
    required String legalName,
    required String shortName,
    required String legalAddress,
    required String actualAddress,
    required String inn,
    required String kpp,
    required String ogrn,
    required String bankName,
    required String bankAccount,
    required String bankBik,
    required String bankCorrAccount,
    required String representativeName,
    required String representativePosition,
    required String representativeBasis,
    required String contractCity,
    required String workSchedule,
    required String salaryTermsTemplate,
    required String retentionPolicy,
    required bool legalDocumentsApproved,
    required String approvedByName,
    required DateTime? approvedAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Нет активной Auth-сессии');
    final payload = <String, dynamic>{
      'company_id': companyId.trim(),
      'legal_name': legalName.trim(),
      'short_name': shortName.trim(),
      'legal_address': legalAddress.trim(),
      'actual_address': actualAddress.trim(),
      'inn': inn.trim(),
      'kpp': kpp.trim(),
      'ogrn': ogrn.trim(),
      'bank_name': bankName.trim(),
      'bank_account': bankAccount.trim(),
      'bank_bik': bankBik.trim(),
      'bank_corr_account': bankCorrAccount.trim(),
      'representative_name': representativeName.trim(),
      'representative_position': representativePosition.trim(),
      'representative_basis': representativeBasis.trim(),
      'contract_city': contractCity.trim(),
      'work_schedule': workSchedule.trim(),
      'salary_terms_template': salaryTermsTemplate.trim(),
      'retention_policy': retentionPolicy.trim(),
      'legal_documents_approved': legalDocumentsApproved,
      'approved_by_name': approvedByName.trim(),
      'approved_at': approvedAt?.toUtc().toIso8601String(),
      'updated_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _client
        .from('company_employer_profiles')
        .upsert(payload, onConflict: 'company_id')
        .select()
        .single();
    return CompanyEmployerProfile.fromMap(_map(row));
  }

  static Future<CompanyPersonalDataGate> saveGate({
    required CompanyPersonalDataGate gate,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Нет активной Auth-сессии');
    final payload = <String, dynamic>{
      'company_id': gate.companyId.trim(),
      'real_documents_enabled': gate.realDocumentsEnabled,
      'russian_storage_location_confirmed':
          gate.russianStorageLocationConfirmed,
      'data_controller_details_approved': gate.dataControllerDetailsApproved,
      'personal_data_consent_approved': gate.personalDataConsentApproved,
      'retention_and_deletion_policy_approved':
          gate.retentionAndDeletionPolicyApproved,
      'download_audit_log_verified': gate.downloadAuditLogVerified,
      'backup_and_restore_tested': gate.backupAndRestoreTested,
      'access_offboarding_tested': gate.accessOffboardingTested,
      'incident_response_owner_assigned': gate.incidentResponseOwnerAssigned,
      'storage_region': gate.storageRegion.trim(),
      'retention_days': gate.retentionDays,
      'deletion_policy': gate.deletionPolicy.trim(),
      'incident_owner': gate.incidentOwner.trim(),
      'approved_by_name': gate.approvedByName.trim(),
      'approved_at': gate.approvedAt?.toUtc().toIso8601String(),
      'updated_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _client
        .from('company_personal_data_gates')
        .upsert(payload, onConflict: 'company_id')
        .select()
        .single();
    return CompanyPersonalDataGate.fromMap(_map(row));
  }

  static Future<void> logAccess({
    required String companyId,
    required String action,
    required String entityType,
    required String entityId,
    String filePath = '',
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Нет активной Auth-сессии');
    await _client.from('personal_data_access_log').insert(<String, dynamic>{
      'company_id': companyId.trim(),
      'user_id': userId,
      'action': action,
      'entity_type': entityType.trim(),
      'entity_id': entityId.trim(),
      'file_path': filePath.trim(),
      'metadata': metadata,
    });
  }
}
