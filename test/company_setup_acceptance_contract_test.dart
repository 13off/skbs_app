import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('first launch has real progress and never seeds production data', () {
    final repository = source(
      'lib/features/company/data/company_setup_repository.dart',
    );
    final screen = source(
      'lib/features/company/presentation/company_setup_screen.dart',
    );
    final nudge = source(
      'lib/features/company/presentation/company_setup_nudge.dart',
    );

    expect(repository, contains("from('employees')"));
    expect(repository, contains("select('id, daily_rate')"));
    expect(repository, contains('_allActiveEmployeesHaveRates'));
    expect(repository, contains("id: 'rates'"));
    expect(repository, contains('Назначьте дневные ставки'));
    expect(repository, contains("from('tasks')"));
    expect(repository, contains("from('attendance')"));
    expect(repository, contains('hasAssignedForeman'));
    expect(screen, contains("title: 'Запуск компании'"));
    expect(screen, contains('не создаёт сотрудников'));
    expect(nudge, contains('company_setup_nudge'));
    expect('$repository\n$screen\n$nudge', isNot(contains('.insert(')));
    expect('$repository\n$screen\n$nudge', isNot(contains('.update(')));
    expect('$repository\n$screen\n$nudge', isNot(contains('.delete(')));
  });

  test('setup remains reachable after the one-time prompt', () {
    final profile = source('lib/screens/profile_screen.dart');
    final system = source(
      'lib/features/developer/presentation/developer_system_screen.dart',
    );
    final main = source('lib/screens/main_screen.dart');

    expect(profile, contains("title: 'Запуск компании'"));
    expect(system, contains("title: 'Запуск компании'"));
    expect(main, contains('CompanySetupNudge'));
  });

  test(
    'role acceptance verifies multiple tables and foreman scope server-side',
    () {
      final repository = source(
        'lib/features/developer/data/role_acceptance_repository.dart',
      );
      final matrix =
          jsonDecode(source('config/role-capability-matrix.json'))
              as Map<String, dynamic>;

      expect(repository, contains('List<RoleAcceptanceProbe> liveProbes'));
      expect(repository, contains('for (final probe in scenario.liveProbes)'));
      expect(
        repository,
        contains('Нарушение: сервер вернул строк с другого объекта'),
      );
      expect(repository, isNot(contains("query = query.eq('object_name'")));
      expect(matrix['schema_version'], 3);
      expect(
        (matrix['principles']
            as Map)['foreman_scope_is_verified_without_client_filter'],
        isTrue,
      );
      for (final role in (matrix['roles'] as List<dynamic>).whereType<Map>()) {
        final acceptance = Map<String, dynamic>.from(role['acceptance'] as Map);
        expect(
          (acceptance['live_probe_tables'] as List<dynamic>).length,
          greaterThan(1),
        );
        expect(
          (acceptance['required_permissions'] as List<dynamic>),
          isNotEmpty,
        );
      }
    },
  );

  test('readiness covers core modules governance and operational AI', () {
    final readiness = source(
      'lib/features/developer/presentation/developer_readiness_screen.dart',
    );

    expect(readiness, contains('Ключевые рабочие таблицы'));
    expect(readiness, contains("from('payments')"));
    expect(readiness, contains("from('app_notifications')"));
    expect(readiness, contains('DataGovernanceRepository.fetchCenter'));
    expect(readiness, contains("'ai-operational-insights'"));
  });

  test('machine acceptance checklist includes workflows and bad states', () {
    final checklist =
        jsonDecode(source('config/acceptance-scenarios.json'))
            as Map<String, dynamic>;

    expect(checklist['automatic_writes'], isFalse);
    expect(checklist['mobile_release'], isFalse);
    expect(
      (checklist['scenarios'] as List<dynamic>).length,
      greaterThanOrEqualTo(9),
    );
    expect(
      (checklist['bad_states'] as List<dynamic>),
      contains('double_submit'),
    );
    expect(
      (checklist['bad_states'] as List<dynamic>),
      contains('concurrent_edit'),
    );
    expect(
      (checklist['bad_states'] as List<dynamic>),
      contains('missing_rate'),
    );
    expect(
      (checklist['rules'] as List<dynamic>),
      contains('profession_directory_is_out_of_scope'),
    );
  });
}
