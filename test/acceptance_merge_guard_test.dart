import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('final acceptance entry points remain connected', () {
    final manager = File(
      'lib/features/reports/presentation/manager_main_screen.dart',
    ).readAsStringSync();
    final recommendation = File(
      'lib/features/company/presentation/company_setup_recommendation_card.dart',
    ).readAsStringSync();
    final setup = File(
      'lib/features/company/data/company_setup_repository.dart',
    ).readAsStringSync();

    expect(manager, contains('CompanySetupRecommendationCard'));
    expect(recommendation, contains('CompanySetupScreen'));
    expect(recommendation, contains('progress.nextRequiredStep'));
    expect(setup, contains("id: 'rates'"));
    expect(setup, contains('_allActiveEmployeesHaveRates'));
  });
}
