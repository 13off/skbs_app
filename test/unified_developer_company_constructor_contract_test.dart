import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Единый конструктор остаётся только в профессиональной платформе разработчика.
void main() {
  test('developer platform has one compact constructor entry point', () {
    final main = File(
      'lib/features/developer/presentation/developer_main_screen.dart',
    ).readAsStringSync();
    final system = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();

    expect(main, contains('static const int pageCount = 2;'));
    expect(main, contains("label: 'Конструктор'"));
    expect(main, isNot(contains("label: 'Контроль'")));
    expect(main, contains("label: 'Профиль'"));
    expect(main, isNot(contains("label: 'Ограничения'")));
    expect(main, isNot(contains("label: 'Права'")));
    expect(main, isNot(contains("label: 'Диспетчер'")));

    expect(system, contains("title: 'Конструктор'"));
    expect(system, contains('Конструктор текущей компании'));
    expect(system, contains('Компания'));
    expect(system, contains('Объект'));
    expect(system, contains('Роль'));
  });

  test('constructor reuses every existing real configuration screen', () {
    final system = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();

    expect(system, contains('DeveloperPanelScreen'));
    expect(system, contains('RolePermissionMatrixScreen'));
    expect(system, contains('DispatcherSettingsScreen'));
    expect(system, contains('DeveloperConstructorScreen'));
    expect(system, contains('CompanyManagementScreen'));
    expect(system, contains('CompanyComplianceScreen'));
    expect(system, contains('TemplateDocumentsScreen'));
    expect(system, contains('NotificationControlCenterScreen'));
    expect(system, contains('PushNotificationSettingsScreen'));
    expect(system, contains('CompanySwitcherScreen'));
    expect(
      File(
        'lib/features/developer/data/developer_company_constructor_repository.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('company and object inheritance stays in existing protected repositories', () {
    final policies = File(
      'lib/features/developer/data/developer_policy_repository.dart',
    ).readAsStringSync();
    final permissions = File(
      'lib/features/developer/data/role_permission_repository.dart',
    ).readAsStringSync();
    final constructor = File(
      'lib/features/developer/data/developer_constructor_repository.dart',
    ).readAsStringSync();

    expect(policies, contains("'get_developer_task_policy_center'"));
    expect(policies, contains("'save_task_policy_setting'"));
    expect(policies, contains("'reset_task_policy_override'"));
    expect(permissions, contains('get_role_permission_center'));
    expect(permissions, contains('save_role_permission_override'));
    expect(permissions, contains('reset_role_permission_override'));
    expect(constructor, contains('get_developer_constructor_center'));
  });

  test('manager platform receives no constructor navigation or screen', () {
    final manager = File(
      'lib/features/reports/presentation/manager_main_screen.dart',
    ).readAsStringSync();

    expect(manager, isNot(contains('DeveloperSystemScreen')));
    expect(manager, isNot(contains('DeveloperPanelScreen')));
    expect(manager, isNot(contains('RolePermissionMatrixScreen')));
    expect(manager, isNot(contains("label: 'Конструктор'")));
    expect(manager, isNot(contains('Конструктор текущей компании')));
  });
}
