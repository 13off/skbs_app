import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('final acceptance entry points remain connected', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final system = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();
    final setup = File(
      'lib/features/company/data/company_setup_repository.dart',
    ).readAsStringSync();

    expect(profile, contains("title: 'Запуск компании'"));
    expect(system, contains("title: 'Запуск компании'"));
    expect(setup, contains("id: 'rates'"));
    expect(setup, contains('_allActiveEmployeesHaveRates'));
  });
}
