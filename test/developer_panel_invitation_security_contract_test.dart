import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('developer system shows one restrictions editor and no fake demo status', () {
    final system = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();
    final platform = File(
      'lib/features/developer/presentation/developer_main_screen.dart',
    ).readAsStringSync();

    expect(platform, contains("label: 'Ограничения'"));
    expect(system, contains('Напоминания и системные параметры'));
    expect(system, contains('отдельной вкладке «Ограничения»'));
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

  test('invitation uses one canonical web publication', () {
    final adapter = File(
      'supabase/functions/invite-company-member/index.ts',
    ).readAsStringSync();
    final core = File(
      'supabase/functions/invite-company-member-core/index.ts',
    ).readAsStringSync();
    final users = File(
      'lib/features/auth/data/user_repository.dart',
    ).readAsStringSync();

    expect(adapter, isNot(contains('13off.github.io/appstroy-web')));
    expect(adapter, isNot(contains('publishedWebAppUrl')));
    expect(adapter, contains('return json(data, coreResponse.status);'));
    expect(core, contains('https://api.appstroy-web.ru/app/'));
    expect(users, contains('https://api.appstroy-web.ru/app/'));
  });

  test('member access is one protected server transaction', () {
    final repository = File(
      'lib/features/company/data/company_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260723260000_harden_tenant_integrity_and_member_updates.sql',
    ).readAsStringSync();

    final methodStart = repository.indexOf(
      'static Future<void> updateMemberAccess',
    );
    final methodEnd = repository.indexOf('\n  }\n}', methodStart);
    final method = repository.substring(methodStart, methodEnd + 4);

    expect(method, contains("'update_company_member_access'"));
    expect(method, isNot(contains(".from('company_memberships')")));
    expect(method, isNot(contains(".from('object_memberships')")));
    expect(method, isNot(contains(".from('user_profiles')")));

    expect(migration, contains('update_company_member_access'));
    expect(migration, contains('object_memberships_company_user_membership_fkey'));
    expect(migration, contains('attendance_company_object_employee_fkey'));
    expect(migration, contains('payments_company_object_employee_fkey'));
    expect(migration, contains('payment_receipts_company_payment_fkey'));
    expect(migration, contains('tasks_company_object_fkey'));
    expect(migration, contains('revoke execute'));
    expect(migration, contains('grant execute'));
  });
}
