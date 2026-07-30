import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const functionPath = 'supabase/functions/employee-team/index.ts';
  const repositoryPath =
      'lib/features/employee/data/employee_team_repository.dart';
  const screenPath =
      'lib/features/employee/presentation/employee_team_screen.dart';
  const tabPath =
      'lib/features/employee/presentation/employee_team_tab_screen.dart';
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
    expect(function, contains('const selectedEmployeeId = cleanText(input.employee_id'));
    expect(function, contains('seedForManager(adminClient, viewer, selectedEmployeeId)'));
    expect(function, contains('.eq("company_id", viewer.companyId)'));
  });

  test('команда отдаёт только простой профиль и контакт коллеги', () {
    final function = File(functionPath).readAsStringSync();
    final responseStart = function.indexOf('return people');
    final responseEnd = function.indexOf('Deno.serve', responseStart);
    final responseBlock = function.substring(responseStart, responseEnd);

    expect(responseBlock, contains('full_name'));
    expect(responseBlock, contains('profession'));
    expect(responseBlock, contains('phone'));
    expect(responseBlock, contains('avatar_url'));
    expect(responseBlock, contains('profile_verified'));
    expect(responseBlock, isNot(contains('daily_rate')));
    expect(responseBlock, isNot(contains('payment')));
    expect(responseBlock, isNot(contains('documents')));
    expect(responseBlock, isNot(contains('skills')));
  });

  test('подтверждение означает активную связь аккаунта с карточкой', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('.from("employee_account_links")'));
    expect(function, contains('.select("person_id, user_id, phone_e164")'));
    expect(function, contains('.from("user_profiles")'));
    expect(function, contains('profile_verified: Boolean(link && profile)'));
  });

  test('аватар закрытого хранилища передаётся временной ссылкой', () {
    final function = File(functionPath).readAsStringSync();
    expect(function, contains('.from("profile-avatars")'));
    expect(function, contains('.createSignedUrls(avatarPaths, 60 * 60)'));
  });

  test('клиент работает только через JWT edge function', () {
    final repository = File(repositoryPath).readAsStringSync();
    expect(repository, contains("'employee-team'"));
    expect(repository, contains("'action': 'list'"));
    expect(repository, isNot(contains(".from('employees')")));
  });

  test('команда временно убрана из нижней панели сотрудника', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final tab = File(tabPath).readAsStringSync();

    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains("label: 'История задач'"));
    expect(wrapper, isNot(contains("label: 'Команда'")));
    expect(wrapper, isNot(contains('EmployeeTeamTabScreen')));
    expect(tab, contains('EmployeeWorkActionRepository.resolveSelection()'));
    expect(tab, contains('EmployeeTeamRepository.fetch(employeeId: selection.employeeId)'));
    expect(tab, isNot(contains('EmployeeRepository.fetchEmployees')));
  });

  test('загрузка команды остаётся внутри вкладки', () {
    final tab = File(tabPath).readAsStringSync();
    expect(tab, contains('CircularProgressIndicator.adaptive()'));
    expect(tab, contains("subtitle: 'Коллеги текущего объекта'"));
    expect(tab, isNot(contains('PremiumLoadingScreen(')));
  });

  test('панель сразу показывает контактный профиль коллеги', () {
    final tab = File(tabPath).readAsStringSync();
    final details = File(screenPath).readAsStringSync();

    expect(tab, contains('Телефон не указан'));
    expect(tab, contains('Профиль подтверждён'));
    expect(tab, contains('Профиль не подтверждён'));
    expect(tab, contains('Здесь показываются только активные сотрудники этого же объекта.'));
    expect(details, contains("title: 'Профиль сотрудника'"));
    expect(details, contains("label: const Text('Скопировать номер')"));
  });

  test('интерфейс команды не пишет рабочие данные напрямую', () {
    final tab = File(tabPath).readAsStringSync();
    expect(tab, isNot(contains("functions.invoke('")));
    expect(tab, isNot(contains(".from('")));
    expect(tab, isNot(contains('.insert(')));
    expect(tab, isNot(contains('.update(')));
  });
}
