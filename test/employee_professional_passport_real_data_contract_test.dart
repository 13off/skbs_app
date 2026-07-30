import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const teamTabPath =
      'lib/features/employee/presentation/employee_team_tab_screen.dart';
  const directoryPath =
      'lib/features/employee/presentation/employee_passport_directory_screen.dart';
  const viewerPath =
      'lib/features/employee/presentation/employee_professional_passport_viewer_screen.dart';
  const repositoryPath =
      'lib/features/employee/data/employee_professional_profile_repository.dart';
  const functionPath =
      'supabase/functions/employee-professional-profile-view/index.ts';
  const detailsPath = 'lib/screens/employee_details/employee_details_view.dart';
  const navigationPath =
      'lib/screens/employee_details/employee_details_navigation.dart';

  test('паспорт и команда убраны из упрощённой панели сотрудника', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final teamTab = File(teamTabPath).readAsStringSync();
    final directory = File(directoryPath).readAsStringSync();

    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains("label: 'История задач'"));
    expect(wrapper, isNot(contains('EmployeeTeamTabScreen')));
    expect(wrapper, isNot(contains('EmployeeProfessionalPassport')));
    expect(wrapper, isNot(contains('EmployeeTeamSeedDirectoryScreen')));
    expect(wrapper, isNot(contains('EmployeeCommunityHubScreen')));
    expect(teamTab, contains('EmployeeWorkActionRepository.resolveSelection()'));
    expect(teamTab, contains('EmployeeTeamRepository.fetch(employeeId: selection.employeeId)'));
    expect(teamTab, isNot(contains('_resolvePreviewSeed')));
    expect(teamTab, isNot(contains('EmployeeRepository.fetchEmployees')));

    expect(directory, contains('EmployeeRepository.fetchEmployees'));
    expect(directory, contains('includeFired: true'));
    expect(directory, contains('_deduplicatePeople'));
    expect(directory, contains('employee.personId'));
    expect(directory, contains('EmployeeProfessionalPassportViewerScreen'));
    expect(directory, isNot(contains('Демонстрационный объект')));
  });

  test('карточка сотрудника открывает его настоящий паспорт', () {
    final details = File(detailsPath).readAsStringSync();
    final navigation = File(navigationPath).readAsStringSync();

    expect(details, contains("title: 'Паспорт специалиста'"));
    expect(details, contains('onTap: openProfessionalPassport'));
    expect(navigation, contains('openProfessionalPassport'));
    expect(navigation, contains('EmployeeProfessionalPassportViewerScreen'));
    expect(navigation, contains('employee: employee'));
  });

  test('просмотр паспорта загружает только реальные серверные данные', () {
    final viewer = File(viewerPath).readAsStringSync();
    final repository = File(repositoryPath).readAsStringSync();

    expect(viewer, contains('fetchForEmployee'));
    expect(viewer, contains('реальные данные AppСтрой'));
    expect(viewer, contains('Подтверждено AppСтрой'));
    expect(viewer, contains('Сотрудник пока не заполнил'));
    expect(viewer, isNot(contains('.preview(')));
    expect(viewer, isNot(contains('Repository.save')));
    expect(viewer, isNot(contains('profile.phone')));
    expect(viewer, isNot(contains('Демонстрационный')));
    expect(repository, contains("'employee-professional-profile-view'"));
    expect(repository, contains("'employee_id': cleanEmployeeId"));
  });

  test('сервер проверяет руководителя и компанию выбранного сотрудника', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('userClient.auth.getUser()'));
    expect(function, contains('.from("user_profiles")'));
    expect(function, contains('viewer.role !== "admin"'));
    expect(function, contains('viewer.role !== "developer"'));
    expect(function, contains('.eq("id", employeeId)'));
    expect(function, contains('.eq("company_id", companyId)'));
    expect(function, contains('selectedEmployee.person_id'));
    expect(function, contains('employee_professional_summary'));
    expect(function, contains('employee_professional_profiles'));
    expect(function, isNot(contains('input.person_id')));
    expect(function, isNot(contains('input.company_id')));
    expect(function, isNot(contains('.upsert(')));
    expect(function, isNot(contains('.update(')));
  });
}
