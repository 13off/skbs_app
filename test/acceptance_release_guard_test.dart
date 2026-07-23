import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acceptance release stays web-only and production-safe', () {
    final config = jsonDecode(
      File('config/acceptance-scenarios.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final setupRepository = File(
      'lib/features/company/data/company_setup_repository.dart',
    ).readAsStringSync();
    final runbook = File(
      'docs/full-acceptance-runbook.md',
    ).readAsStringSync();

    expect(config['mode'], 'production_safe');
    expect(config['automatic_writes'], isFalse);
    expect(config['mobile_release'], isFalse);
    expect(setupRepository, isNot(contains('.insert(')));
    expect(setupRepository, isNot(contains('.update(')));
    expect(setupRepository, isNot(contains('.delete(')));
    expect(runbook, contains('отдельной тестовой компании'));
    expect(runbook, contains('Режим просмотра роли'));
    expect(
      (config['rules'] as List<dynamic>),
      contains('profession_directory_is_out_of_scope'),
    );
  });
}
