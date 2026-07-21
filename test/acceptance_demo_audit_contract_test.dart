import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ролевой контракт требует настоящий JWT и остаётся read-only', () {
    final repository = File(
      'lib/features/developer/data/role_acceptance_repository.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/developer/presentation/developer_role_acceptance_screen.dart',
    ).readAsStringSync();

    expect(repository, contains("rpc('current_user_role')"));
    expect(repository, contains("rpc('current_user_company_id')"));
    expect(repository, contains("rpc('current_user_object_name')"));
    expect(repository, contains("rpc(\n        'current_user_has_permission'"));
    expect(repository, contains("select('id')"));
    expect(screen, contains('Клиентский просмотр роли не используется как доказательство'));
    expect('$repository\n$screen', isNot(contains('.insert(')));
    expect('$repository\n$screen', isNot(contains('.update(')));
    expect('$repository\n$screen', isNot(contains('.delete(')));
    expect('$repository\n$screen', isNot(contains('service_role')));
  });

  test('машинная матрица содержит live-приёмку каждой роли', () {
    final matrix = jsonDecode(
      File('config/role-capability-matrix.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final principles = Map<String, dynamic>.from(
      matrix['principles'] as Map,
    );
    final roles = (matrix['roles'] as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

    expect(matrix['schema_version'], 2);
    expect(principles['live_acceptance_requires_real_role_account'], isTrue);
    expect(principles['acceptance_is_read_only'], isTrue);
    for (final role in roles) {
      final acceptance = Map<String, dynamic>.from(role['acceptance'] as Map);
      expect(acceptance['live_probe_table'].toString().trim(), isNotEmpty);
      expect(acceptance['required_permissions'], isA<List<dynamic>>());
      expect(acceptance['forbidden_permissions'], isA<List<dynamic>>());
    }
  });

  test('бухгалтер получает прямой единый контроль без команды в чате', () {
    final main = File(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    ).readAsStringSync();
    final reports = File(
      'lib/features/accounting/presentation/accounting_reports_screen.dart',
    ).readAsStringSync();
    final launcher = File(
      'lib/features/ai/presentation/operational_audit_launcher_screen.dart',
    ).readAsStringSync();

    expect(main, contains('pageCount = 5'));
    expect(main, contains("label: 'Контроль'"));
    expect(reports, contains("title: 'Единый контроль'"));
    expect(launcher, contains('AiAssistantRepository.request'));
    expect(launcher, contains("action.type != 'find_operational_anomalies'"));
    expect(launcher, contains('Прямой read-only аудит без команды в чате'));
    expect(launcher, isNot(contains('.insert(')));
    expect(launcher, isNot(contains('.update(')));
    expect(launcher, isNot(contains('.delete(')));
  });

  test('демонстрационный центр не подключается к рабочей базе', () {
    final screen = File(
      'lib/features/developer/presentation/developer_demo_center_screen.dart',
    ).readAsStringSync();
    final demo = jsonDecode(
      File('config/demo-scenario.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(screen, contains('все данные вымышлены'));
    expect(screen, contains('не подключается к Supabase'));
    expect(screen, isNot(contains('supabase_flutter')));
    expect(screen, isNot(contains('Supabase.instance')));
    expect(demo['mode'], 'synthetic_only');
    expect(demo['contains_personal_data'], isFalse);
    expect(demo['uses_production_company'], isFalse);
    expect(demo['uses_production_storage'], isFalse);
    expect((demo['forbidden_during_demo'] as List<dynamic>), isNotEmpty);
  });

  test('кадровый путь сохраняет тестовый режим и не придумывает ставку', () {
    final onboarding = File(
      'lib/features/recruitment/presentation/recruitment_onboarding_screen.dart',
    ).readAsStringSync();
    final draft = File(
      'lib/features/ai/presentation/ai_employee_draft_screen.dart',
    ).readAsStringSync();

    expect(onboarding, contains('isTestRecord: candidate.isTestRecord'));
    expect(onboarding, contains("'daily_rate': 0"));
    expect(onboarding, contains('Готовность оформления'));
    expect(onboarding, contains('Следующий шаг:'));
    expect(onboarding, contains('Блокер: не заполнено обязательных полей'));
    expect(draft, contains('Ставка и объект требуют ручной проверки'));
    expect(draft, contains('Введите согласованную ставку'));
    expect(draft, isNot(contains('rate > 0 ? rate : 6000')));
    expect(draft, isNot(contains('(rate > 0 ? rate : 6000)')));
  });

  test('коммерческая приёмка и сценарий показа задокументированы', () {
    final demo = File('docs/commercial-demo.md').readAsStringSync();
    final readiness = File(
      'docs/acceptance-and-market-readiness.md',
    ).readAsStringSync();

    expect(demo, contains('Управление объектом'));
    expect(demo, contains('Кандидат → сотрудник'));
    expect(demo, contains('Табель и выплаты'));
    expect(demo, contains('не открывать рабочие паспорта'));
    expect(readiness, contains('Ролевая готовность'));
    expect(readiness, contains('Операционная готовность'));
    expect(readiness, contains('Коммерческая готовность'));
    expect(readiness, contains('отдельная тестовая учётная запись'));
  });

  test('системная платформа связывает все новые центры', () {
    final system = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();

    expect(system, contains("title: 'Ролевая приёмка'"));
    expect(system, contains("title: 'Контроль табеля и выплат'"));
    expect(system, contains("title: 'Демонстрационный центр'"));
    expect(system, contains('DeveloperRoleAcceptanceScreen'));
    expect(system, contains('OperationalAuditLauncherScreen'));
    expect(system, contains('DeveloperDemoCenterScreen'));
  });
}
