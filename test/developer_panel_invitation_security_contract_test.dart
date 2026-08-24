import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('developer platform keeps one constructor and no fake demo status', () {
    final system = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();
    final platform = File(
      'lib/features/developer/presentation/developer_main_screen.dart',
    ).readAsStringSync();

    expect(platform, contains('static const int pageCount = 2;'));
    expect(platform, contains("label: 'Конструктор'"));
    expect(platform, isNot(contains("label: 'Ограничения'")));
    expect(platform, isNot(contains("label: 'Права'")));
    expect(platform, isNot(contains("label: 'Диспетчер'")));
    expect(system, contains("title: 'Ограничения задач и объектов'"));
    expect(system, contains("title: 'Роли и права'"));
    expect(system, contains("title: 'Напоминания и системные параметры'"));
    expect(system, contains('DeveloperPanelScreen'));
    expect(system, contains('RolePermissionMatrixScreen'));
    expect(system, contains('DispatcherSettingsScreen'));
    expect(system, contains('DeveloperConstructorScreen'));
    expect(system, isNot(contains('DeveloperDemoCenterScreen')));
    expect(system, isNot(contains('База подключена')));
    expect(system, isNot(contains('Планировщик активен')));
    expect(system, isNot(contains('Push-контур активен')));
    expect(system, isNot(contains('ИИ-диспетчер готов')));
  });

  test('role acceptance checks only the actual authenticated session', () {
    final screen = File(
      'lib/features/developer/presentation/developer_role_acceptance_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('Проверка текущей роли'));
    expect(screen, contains('реально авторизованная роль этой сессии'));
    expect(screen, isNot(contains('ChoiceChip')));
    expect(screen, isNot(contains('Выбери профессию')));
    expect(screen, isNot(contains('selectRole(')));
  });

  test('invitation uses one canonical public landing with Russian API verify', () {
    final adapter = File(
      'supabase/functions/invite-company-member/index.ts',
    ).readAsStringSync();
    final core = File(
      'supabase/functions/invite-company-member-core/index.ts',
    ).readAsStringSync();
    final users = File(
      'lib/features/auth/data/user_repository.dart',
    ).readAsStringSync();
    final landing = File('web/invite.html').readAsStringSync();

    expect(adapter, contains('https://13off.github.io/appstroy-web/'));
    expect(adapter, contains('publishedWebAppUrl'));
    expect(adapter, contains('publicInvitationUrl'));
    expect(adapter, contains('return json(data, coreResponse.status);'));
    expect(adapter, isNot(contains('https://api.appstroy-web.ru/app/')));

    // Token generation and tenant/role decisions remain in the protected core.
    expect(core, contains('https://api.appstroy-web.ru/app/'));
    expect(core, contains('generateLink'));
    expect(core, contains('properties?.hashed_token'));

    // Client fallback may still know the Russian app mirror, but copied invites
    // are server-rewritten to the canonical public landing above.
    expect(users, contains('https://api.appstroy-web.ru/app/'));
    expect(
      landing,
      contains("const supabaseUrl = 'https://api.appstroy-web.ru'"),
    );
    expect(landing, contains('/auth/v1/verify'));
  });

  test('member access is one protected server transaction', () {
    final repository = File(
      'lib/features/company/data/company_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260723260000_harden_tenant_integrity_and_member_updates.sql',
    ).readAsStringSync();

    final normalizedRepository = repository.replaceAll('\r\n', '\n');
    final methodStart = normalizedRepository.indexOf(
      'static Future<void> updateMemberAccess',
    );
    final methodEnd = normalizedRepository.indexOf('\n  }\n}', methodStart);
    final method = methodStart < 0 || methodEnd < 0
        ? null
        : normalizedRepository.substring(methodStart, methodEnd + 4);

    expect(method, isNotNull);
    expect(method, contains("'update_company_member_access'"));
    expect(method, isNot(contains(".from('company_memberships')")));
    expect(method, isNot(contains(".from('object_memberships')")));
    expect(method, isNot(contains(".from('user_profiles')")));

    expect(migration, contains('update_company_member_access'));
    expect(
      migration,
      contains('object_memberships_company_user_membership_fkey'),
    );
    expect(migration, contains('attendance_company_object_employee_fkey'));
    expect(migration, contains('payments_company_object_employee_fkey'));
    expect(migration, contains('payment_receipts_company_payment_fkey'));
    expect(migration, contains('tasks_company_object_fkey'));
    expect(migration, contains('revoke execute'));
    expect(migration, contains('grant execute'));
  });
}
