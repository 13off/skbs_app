import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HR получает отдельную вкладку оформления', () {
    final main = File(
      'lib/features/recruitment/presentation/recruitment_main_screen.dart',
    ).readAsStringSync();
    expect(main, contains('RecruitmentOnboardingScreen'));
    expect(main, contains("label: 'Оформление'"));
    expect(main, contains('pageCount = 4'));
  });

  test('оформление сохраняет четыре независимых статуса форм', () {
    final migration = File(
      'supabase/migrations/20260721170000_candidate_onboarding_forms.sql',
    ).readAsStringSync();
    expect(migration, contains('recruitment_onboarding_forms'));
    expect(migration, contains('ready_to_print'));
    expect(migration, contains('printed'));
    expect(migration, contains('signed'));
    expect(migration, contains('unique (company_id, application_id, form_code)'));
    expect(migration, contains('recruitment.documents.edit'));
    expect(migration, contains('enable row level security'));
  });

  test('подписанные файлы загружаются только в закрытый bucket', () {
    final repository = File(
      'lib/features/recruitment/data/candidate_onboarding_repository.dart',
    ).readAsStringSync();
    expect(repository, contains("storageBucket = 'recruitment-documents'"));
    expect(repository, contains('maxSignedFileBytes'));
    expect(repository, contains('.uploadBinary('));
    expect(repository, contains('.createSignedUrl('));
    expect(repository, isNot(contains('getPublicUrl')));
    expect(repository, isNot(contains('service_role')));
  });

  test('комплект подтягивает закрытые данные связанного сотрудника', () {
    final service = File(
      'lib/features/recruitment/data/candidate_onboarding_package_service.dart',
    ).readAsStringSync();
    expect(service, contains('EmployeePrivateDataRepository.fetchByEmployeeId'));
    expect(service, contains("'passport_series'"));
    expect(service, contains("'bank_account'"));
    expect(service, contains("'employee_snils'"));
    expect(service, contains('ExactDocxService.build'));
    expect(service, contains('candidateOnboardingFormCodes'));
    expect(service, contains('ТЕСТ_'));
  });

  test('создание сотрудника остаётся ручным и связывает заявку', () {
    final screen = File(
      'lib/features/recruitment/presentation/recruitment_onboarding_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/recruitment/data/candidate_onboarding_repository.dart',
    ).readAsStringSync();
    expect(screen, contains('AiEmployeeDraftScreen'));
    expect(screen, contains('Создать сотрудника без повторного ввода'));
    expect(repository, contains("'employee_id': cleanEmployeeId"));
    expect(repository, contains("'status': 'hired'"));
    expect(screen, isNot(contains(".from('employees').insert")));
  });

  test('реальные документы не объявлены готовыми без legal review', () {
    final service = File(
      'lib/features/recruitment/data/candidate_onboarding_package_service.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/recruitment/presentation/recruitment_onboarding_screen.dart',
    ).readAsStringSync();
    expect(service, contains('юридического утверждения'));
    expect(screen, contains('production gate'));
    expect(screen, contains('обезличенные или тестовые копии'));
  });
}
