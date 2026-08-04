import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260729213500_employee_professional_passport.sql';
  const functionPath =
      'supabase/functions/employee-professional-profile/index.ts';
  const repositoryPath =
      'lib/features/employee/data/employee_professional_profile_repository.dart';
  const screenPath =
      'lib/features/employee/presentation/employee_professional_passport_screen.dart';
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const appMainPath = 'lib/main.dart';

  test('профессиональный паспорт хранится в закрытом контуре', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('employee_professional_profiles'));
    expect(migration, contains('primary key (company_id, person_id)'));
    expect(migration, contains('unique (company_id, user_id)'));
    expect(migration, contains('enable row level security'));
    expect(
      migration,
      contains('revoke all on table public.employee_professional_profiles'),
    );
    expect(migration, contains('from anon, authenticated'));
    expect(migration, contains('to service_role'));
    expect(migration, isNot(contains('create policy')));
  });

  test('подтверждённая история считается по рабочим данным за всё время', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('employee_professional_summary'));
    expect(migration, contains('sum(a.shifts)'));
    expect(migration, contains('sum(a.hours)'));
    expect(migration, contains('min(a.work_date)'));
    expect(migration, contains("t.status = 'Выполнено'"));
    expect(migration, contains('count(distinct t.id)'));
    expect(migration, contains('object_names'));
  });

  test('сервер принимает только действующего сотрудника текущей сессии', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('userClient.auth.getUser()'));
    expect(function, contains('.eq("role", "employee")'));
    expect(function, contains('.eq("is_active", true)'));
    expect(function, contains('.from("employee_account_links")'));
    expect(function, contains('identity.companyId'));
    expect(function, contains('identity.personId'));
    expect(function, isNot(contains('input.company_id')));
    expect(function, isNot(contains('input.person_id')));
    expect(function, isNot(contains('input.user_id')));
  });

  test('сервер ограничивает редактируемые поля паспорта', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('cleanList(input.skills, 20, 50)'));
    expect(function, contains('cleanParagraph(input.about, 800)'));
    expect(function, contains('cleanList(input.preferred_cities, 12, 80)'));
    expect(function, contains('onConflict: "company_id,person_id"'));
    expect(function, isNot(contains('phone_e164: input')));
    expect(function, isNot(contains('full_name: input')));
    expect(function, isNot(contains('total_shifts: input')));
  });

  test('репозиторий использует отдельную edge function', () {
    final repository = File(repositoryPath).readAsStringSync();

    expect(repository, contains("'employee-professional-profile'"));
    expect(repository, contains("'action': 'fetch'"));
    expect(repository, contains("'action': 'update'"));
    expect(
      repository,
      isNot(contains(".from('employee_professional_profiles')")),
    );
  });

  test('паспорт сохранён в системе, но убран из рабочего кабинета', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();
    final details = File(
      'lib/screens/employee_details/employee_details_view.dart',
    ).readAsStringSync();

    expect(
      main,
      contains(
        "import '../features/employee/presentation/employee_platform_with_passport.dart';",
      ),
    );
    expect(main, contains('EmployeePlatformWithPassport('));
    expect(main, contains('initialEmployeeId: previewEmployeeId'));
    expect(wrapper, contains("navigationStorageKey: 'employee-work-simple'"));
    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains("label: 'История задач'"));
    expect(wrapper, isNot(contains('EmployeeProfessionalPassport')));
    expect(wrapper, isNot(contains('EmployeeTeamTabScreen')));
    expect(details, contains("title: 'Паспорт специалиста'"));
  });

  test('экран паспорта продолжает работать вне панели сотрудника', () {
    final screen = File(screenPath).readAsStringSync();

    expect(screen, contains('Паспорт специалиста'));
    expect(screen, contains('Подтверждено работой'));
    expect(screen, contains('О специалисте'));
    expect(screen, contains('Навыки'));
    expect(screen, contains('Готовность к работе'));
    expect(screen, contains('Подтверждено AppСтрой'));
  });

  test('русская дата паспорта инициализируется до runApp', () {
    final appMain = File(appMainPath).readAsStringSync();
    final bindingIndex = appMain.indexOf(
      'WidgetsFlutterBinding.ensureInitialized()',
    );
    final localeIndex = appMain.indexOf(
      "await initializeDateFormatting('ru_RU')",
    );
    final runAppIndex = appMain.indexOf('runApp(');

    expect(
      appMain,
      contains("import 'package:intl/date_symbol_data_local.dart';"),
    );
    expect(bindingIndex, greaterThanOrEqualTo(0));
    expect(localeIndex, greaterThan(bindingIndex));
    expect(runAppIndex, greaterThan(localeIndex));
  });

  test('редактирование паспорта не пишет в базу напрямую из интерфейса', () {
    final screen = File(screenPath).readAsStringSync();

    expect(screen, contains('EmployeeProfessionalProfileRepository.save('));
    expect(screen, isNot(contains("functions.invoke('")));
    expect(screen, isNot(contains(".from('")));
    expect(screen, isNot(contains('.insert(')));
    expect(screen, isNot(contains('.upsert(')));
    expect(screen, isNot(contains('.update(')));
  });
}
