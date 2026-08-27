import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('employee onboarding does not require personal data consent', () {
    final screen = File(
      'lib/features/recruitment/presentation/recruitment_onboarding_screen.dart',
    ).readAsStringSync();
    final models = File(
      'lib/features/recruitment/models/candidate_onboarding_models.dart',
    ).readAsStringSync();
    final packageService = File(
      'lib/features/recruitment/data/candidate_onboarding_package_service.dart',
    ).readAsStringSync();

    expect(
      screen,
      isNot(contains('Сначала нужно подтвердить согласие на обработку данных')),
    );
    expect(screen, isNot(contains("label: 'Согласие'")));
    expect(
      packageService,
      isNot(
        contains(
          'Нельзя сформировать комплект без подтверждённого согласия кандидата',
        ),
      ),
    );
    expect(
      packageService,
      isNot(contains('Согласие на обработку данных:')),
    );

    final codesStart = models.indexOf(
      'const List<String> candidateOnboardingFormCodes',
    );
    final codesEnd = models.indexOf(
      'String candidateOnboardingFormTitle',
      codesStart,
    );
    expect(codesStart, greaterThanOrEqualTo(0));
    expect(codesEnd, greaterThan(codesStart));
    final activeCodes = models.substring(codesStart, codesEnd);
    expect(activeCodes, isNot(contains("'personal_data_consent'")));
    expect(activeCodes, contains("'employment_application'"));
    expect(activeCodes, contains("'salary_transfer_application'"));
    expect(activeCodes, contains("'employment_contract'"));

    expect(screen, contains('candidate.isLinkedToEmployee'));
    expect(packageService, contains('compliance.realDocumentsAllowed'));
  });
}
