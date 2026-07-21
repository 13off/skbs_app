import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/compliance/models/company_compliance_models.dart';

void main() {
  test('production gate требует все восемь доказательств и реквизиты', () {
    const gate = CompanyPersonalDataGate(
      companyId: 'company-test',
      realDocumentsEnabled: true,
      russianStorageLocationConfirmed: true,
      dataControllerDetailsApproved: true,
      personalDataConsentApproved: true,
      retentionAndDeletionPolicyApproved: true,
      downloadAuditLogVerified: true,
      backupAndRestoreTested: true,
      accessOffboardingTested: true,
      incidentResponseOwnerAssigned: true,
      storageRegion: 'Россия, тестовый регион',
      retentionDays: 365,
      deletionPolicy: 'Тестовая политика удаления',
      incidentOwner: 'Тестовый ответственный',
      approvedByName: 'Тестовый утверждающий',
      approvedAt: null,
    );

    expect(gate.completedEvidenceCount, 8);
    expect(gate.allEvidenceComplete, isFalse);
  });

  test('реальные документы разрешаются только утверждённым snapshot', () {
    final snapshot = CompanyComplianceSnapshot(
      employer: CompanyEmployerProfile(
        companyId: 'company-test',
        legalName: 'Тестовая организация',
        legalAddress: 'Тестовый адрес',
        inn: '0000000000',
        kpp: '000000000',
        ogrn: '0000000000000',
        representativeName: 'Тестовый Представитель',
        representativePosition: 'Директор',
        representativeBasis: 'Устав',
        contractCity: 'Тестовый город',
        workSchedule: 'Тестовый график',
        retentionPolicy: 'Тестовый порядок хранения',
        legalDocumentsApproved: true,
        approvedByName: 'Тестовый юрист',
        approvedAt: DateTime(2026, 7, 21),
      ),
      gate: CompanyPersonalDataGate(
        companyId: 'company-test',
        realDocumentsEnabled: true,
        russianStorageLocationConfirmed: true,
        dataControllerDetailsApproved: true,
        personalDataConsentApproved: true,
        retentionAndDeletionPolicyApproved: true,
        downloadAuditLogVerified: true,
        backupAndRestoreTested: true,
        accessOffboardingTested: true,
        incidentResponseOwnerAssigned: true,
        storageRegion: 'Россия, тестовый регион',
        retentionDays: 365,
        deletionPolicy: 'Тестовая политика удаления',
        incidentOwner: 'Тестовый ответственный',
        approvedByName: 'Тестовый утверждающий',
        approvedAt: DateTime(2026, 7, 21),
      ),
    );

    expect(snapshot.realDocumentsAllowed, isTrue);
  });

  test('кадровый ZIP использует серверный gate и профиль работодателя', () {
    final service = File(
      'lib/features/recruitment/data/candidate_onboarding_package_service.dart',
    ).readAsStringSync();

    expect(service, contains('compliance.realDocumentsAllowed'));
    expect(service, contains('candidate.isTestRecord'));
    expect(service, contains('employer.employerDetails'));
    expect(service, isNot(contains("'ООО «СКБС»'")));
    expect(service, isNot(contains('Ермолиной'));
  });

  test('доступ к подписанным документам журналируется и блокируется gate', () {
    final repository = File(
      'lib/features/recruitment/data/candidate_onboarding_repository.dart',
    ).readAsStringSync();
    final complianceRepository = File(
      'lib/features/compliance/data/company_compliance_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('_assertDocumentAccessAllowed'));
    expect(repository, contains("action: 'generate'"));
    expect(repository, contains("action: replacing ? 'replace' : 'upload'"));
    expect(repository, contains("action: 'view'"));
    expect(repository, contains('CompanyComplianceRepository.logAccess'));
    expect(complianceRepository, contains("from('personal_data_access_log')"));
  });

  test('миграции создают защищённый compliance и mobilization контур', () {
    final compliance = File(
      'supabase/migrations/20260721193000_company_compliance_and_personal_data_gate.sql',
    ).readAsStringSync();
    final mobilization = File(
      'supabase/migrations/20260721194000_employee_mobilization_workflow.sql',
    ).readAsStringSync();

    expect(compliance, contains('company_employer_profiles'));
    expect(compliance, contains('company_personal_data_gates'));
    expect(compliance, contains('personal_data_access_log'));
    expect(compliance, contains('enable row level security'));
    expect(compliance, contains('validate_company_personal_data_gate'));
    expect(mobilization, contains('employee_mobilizations'));
    expect(mobilization, contains('prepare_employee_mobilization'));
    expect(mobilization, contains("'foreman'"));
    expect(mobilization, contains("'accountant'"));
    expect(mobilization, contains('update public.employees'));
    expect('$compliance\n$mobilization', isNot(contains('service_role')));
  });

  test('HR получил отдельную вкладку выхода на объект', () {
    final mainScreen = File(
      'lib/features/recruitment/presentation/recruitment_main_screen.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/recruitment/presentation/recruitment_mobilization_screen.dart',
    ).readAsStringSync();

    expect(mainScreen, contains('pageCount = 5'));
    expect(mainScreen, contains("label: 'Выход'"));
    expect(screen, contains('Билеты оформлены'));
    expect(screen, contains('Медицинский допуск получен'));
    expect(screen, contains('Включён в табель'));
  });
}
