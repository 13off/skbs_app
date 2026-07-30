import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260730093000_employee_object_team_visibility.sql';
  const functionPath = 'supabase/functions/employee-team/index.ts';
  const repositoryPath =
      'lib/features/employee/data/employee_team_repository.dart';
  const hubPath =
      'lib/features/employee/presentation/employee_community_hub_screen.dart';
  const screenPath =
      'lib/features/employee/presentation/employee_team_screen.dart';
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';

  test('расширенный профиль имеет явную настройку видимости', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('visibility_scope'));
    expect(migration, contains("default 'object'"));
    for (final scope in <String>[
      "'private'",
      "'object'",
      "'company'",
      "'employers'",
    ]) {
      expect(migration, contains(scope));
    }
    expect(migration, contains('employee_professional_profiles_visibility_idx'));
  });

  test('сервер сам определяет сотрудника, компанию и текущий объект', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('userClient.auth.getUser()'));
    expect(function, contains('.from("user_profiles")'));
    expect(function, contains('.from("employee_account_links")'));
    expect(function, contains('.eq("company_id", viewer.companyId)'));
    expect(function, contains('.eq("person_id", String(link.person_id))'));
    expect(function, contains('.eq("is_active", true)'));
    expect(function, contains('.is("archived_at", null)'));
    expect(function, contains('query.eq("object_id", seed.objectId)'));
    expect(function, contains('query.eq("object_name", seed.objectName)'));
    expect(function, isNot(contains('input.company_id')));
    expect(function, isNot(contains('input.person_id')));
  });

  test('руководитель может проверить только сотрудника своей компании', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('viewer.role === "admin"'));
    expect(function, contains('viewer.role === "developer"'));
    expect(
      function,
      contains('const selectedEmployeeId = cleanText(input.employee_id'),
    );
    expect(function, contains('seedForManager(adminClient, viewer, selectedEmployeeId)'));
    expect(function, contains('.eq("company_id", viewer.companyId)'));
  });

  test('команда не отдаёт личные и расчётные данные', () {
    final function = File(functionPath).readAsStringSync();
    final responseStart = function.indexOf('return people');
    final responseEnd = function.indexOf('Deno.serve', responseStart);
    expect(responseStart, greaterThanOrEqualTo(0));
    expect(responseEnd, greaterThan(responseStart));
    final responseBlock = function.substring(responseStart, responseEnd);

    expect(responseBlock, contains('full_name'));
    expect(responseBlock, contains('profession'));
    expect(responseBlock, contains('total_shifts'));
    expect(responseBlock, contains('completed_tasks'));
    expect(responseBlock, isNot(contains('phone')));
    expect(responseBlock, isNot(contains('daily_rate')));
    expect(responseBlock, isNot(contains('payment')));
    expect(responseBlock, isNot(contains('comment')));
    expect(responseBlock, isNot(contains('documents')));
  });

  test('private скрывает расширенную профессиональную часть', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('const extendedVisible = managerView || scope !== "private"'));
    expect(function, contains('grade: extendedVisible ?'));
    expect(function, contains('skills: extendedVisible ?'));
    expect(function, contains('about: extendedVisible ?'));
    expect(function, contains('Видимость меняет только сам сотрудник'));
  });

  test('клиент работает только через JWT edge function', () {
    final repository = File(repositoryPath).readAsStringSync();

    expect(repository, contains("'employee-team'"));
    expect(repository, contains("'action': 'list'"));
    expect(repository, contains("'action': 'update_visibility'"));
    expect(repository, isNot(contains(".from('employees')")));
    expect(repository, isNot(contains(".from('employee_professional_profiles')")));
  });

  test('платформа открывает рабочую команду и сохраняет паспорт', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final hub = File(hubPath).readAsStringSync();
    final screen = File(screenPath).readAsStringSync();

    expect(wrapper, contains("label: 'Команда'"));
    expect(wrapper, contains('EmployeeCommunityHubScreen'));
    expect(hub, contains('Команда объекта'));
    expect(hub, contains('Мой паспорт специалиста'));
    expect(hub, contains('EmployeeProfessionalPassportScreen'));
    expect(hub, contains('EmployeePassportDirectoryScreen'));
    expect(hub, contains('EmployeeTeamSeedDirectoryScreen'));
    expect(screen, contains('EmployeeRepository.fetchEmployees'));
    expect(screen, contains('EmployeeTeamRepository.fetch'));
    expect(screen, contains('Кто видит мой профиль'));
    expect(screen, contains('Расширенный профиль скрыт'));
    expect(screen, contains('Скопировать безопасный профиль'));
  });

  test('интерфейс команды не пишет рабочие данные напрямую', () {
    final screen = File(screenPath).readAsStringSync();

    expect(screen, isNot(contains("functions.invoke('")));
    expect(screen, isNot(contains(".from('")));
    expect(screen, isNot(contains('.insert(')));
    expect(screen, isNot(contains('.upsert(')));
    expect(screen, isNot(contains('.update(')));
  });
}
