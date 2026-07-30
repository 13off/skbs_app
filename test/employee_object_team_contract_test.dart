import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Фиксирует простой контактный формат команды без профессионального каталога.
void main() {
  const functionPath = 'supabase/functions/employee-team/index.ts';
  const repositoryPath =
      'lib/features/employee/data/employee_team_repository.dart';
  const screenPath =
      'lib/features/employee/presentation/employee_team_screen.dart';
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';

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

    expect(function, contains('viewer.role === "employee"'));
    expect(
      function,
      contains('const selectedEmployeeId = cleanText(input.employee_id'),
    );
    expect(
      function,
      contains('seedForManager(adminClient, viewer, selectedEmployeeId)'),
    );
    expect(function, contains('.eq("company_id", viewer.companyId)'));
  });

  test('команда отдаёт только простой профиль и контакт коллеги', () {
    final function = File(functionPath).readAsStringSync();
    final responseStart = function.indexOf('return people');
    final responseEnd = function.indexOf('Deno.serve', responseStart);
    expect(responseStart, greaterThanOrEqualTo(0));
    expect(responseEnd, greaterThan(responseStart));
    final responseBlock = function.substring(responseStart, responseEnd);

    expect(responseBlock, contains('full_name'));
    expect(responseBlock, contains('profession'));
    expect(responseBlock, contains('phone'));
    expect(responseBlock, contains('avatar_url'));
    expect(responseBlock, contains('profile_verified'));
    expect(responseBlock, isNot(contains('daily_rate')));
    expect(responseBlock, isNot(contains('payment')));
    expect(responseBlock, isNot(contains('comment')));
    expect(responseBlock, isNot(contains('documents')));
    expect(responseBlock, isNot(contains('total_shifts')));
    expect(responseBlock, isNot(contains('completed_tasks')));
    expect(responseBlock, isNot(contains('skills')));
    expect(responseBlock, isNot(contains('about')));
  });

  test('подтверждение означает активную связь аккаунта с карточкой', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('.from("employee_account_links")'));
    expect(function, contains('.select("person_id, user_id, phone_e164")'));
    expect(function, contains('.from("user_profiles")'));
    expect(function, contains('.select("id, phone, avatar_path, is_active")'));
    expect(function, contains('profile_verified: Boolean(link && profile)'));
  });

  test('аватар закрытого хранилища передаётся временной ссылкой', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('.from("profile-avatars")'));
    expect(function, contains('.createSignedUrls(avatarPaths, 60 * 60)'));
    expect(function, contains('avatarUrlMap'));
  });

  test('клиент работает только через JWT edge function', () {
    final repository = File(repositoryPath).readAsStringSync();

    expect(repository, contains("'employee-team'"));
    expect(repository, contains("'action': 'list'"));
    expect(repository, contains('profileVerified'));
    expect(repository, contains('avatarUrl'));
    expect(repository, isNot(contains('updateVisibility')));
    expect(repository, isNot(contains(".from('employees')")));
    expect(repository, isNot(contains(".from('user_profiles')")));
  });

  test('нижняя вкладка сразу открывает простую команду', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final screen = File(screenPath).readAsStringSync();

    expect(wrapper, contains("label: 'Команда'"));
    expect(wrapper, contains('EmployeeTeamScreen'));
    expect(wrapper, contains('EmployeeTeamSeedDirectoryScreen'));
    expect(wrapper, isNot(contains('EmployeeCommunityHubScreen')));
    expect(screen, contains('Профиль сотрудника'));
    expect(screen, contains('Телефон'));
    expect(screen, contains('Профиль подтверждён'));
    expect(screen, contains('Профиль не подтверждён'));
    expect(screen, contains('Здесь показываются только активные сотрудники этого же объекта.'));
    expect(screen, isNot(contains('Кто видит мой профиль')));
    expect(screen, isNot(contains('Скопировать безопасный профиль')));
    expect(screen, isNot(contains('Навыки')));
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
