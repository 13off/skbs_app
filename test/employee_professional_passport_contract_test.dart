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
  const overridePath = 'lib/navigation/platform_tab_override_scope.dart';
  const navigationPath = 'lib/widgets/professional_bottom_navigation.dart';
  const shellPath =
      'lib/features/shell/presentation/persistent_tab_shell.dart';
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
    expect(migration, contains('grant all on table'));
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
    expect(migration, contains('recruitment_onboarding_forms'));
    expect(migration, contains('legal_documents'));
    expect(migration, contains('grant execute'));
    expect(migration, contains('to service_role'));
  });

  test('сервер принимает только действующего сотрудника из текущей сессии', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('userClient.auth.getUser()'));
    expect(function, contains('.eq("id", userId)'));
    expect(function, contains('.eq("role", "employee")'));
    expect(function, contains('.eq("is_active", true)'));
    expect(function, contains('.from("employee_account_links")'));
    expect(function, contains('.eq("user_id", userId)'));
    expect(function, contains('identity.companyId'));
    expect(function, contains('identity.personId'));
    expect(function, contains('identity.userId'));
    expect(function, isNot(contains('input.company_id')));
    expect(function, isNot(contains('input.person_id')));
    expect(function, isNot(contains('input.user_id')));
  });

  test('сервер ограничивает редактируемые поля паспорта', () {
    final function = File(functionPath).readAsStringSync();

    expect(function, contains('cleanList(input.skills, 20, 50)'));
    expect(function, contains('cleanParagraph(input.about, 800)'));
    expect(function, contains('cleanList(input.preferred_cities, 12, 80)'));
    expect(function, contains('Math.min(70'));
    expect(function, contains('10_000_000'));
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
    expect(repository, contains('EmployeeProfessionalPassportData'));
    expect(repository, contains('EmployeeProfessionalProfile'));
    expect(repository, contains('EmployeeProfessionalVerified'));
    expect(repository, isNot(contains(".from('employee_professional_profiles')")));
  });

  test('паспорт сохранён, а команда встроена в обычную вкладку', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final wrapper = File(wrapperPath).readAsStringSync();
    final override = File(overridePath).readAsStringSync();
    final navigation = File(navigationPath).readAsStringSync();
    final shell = File(shellPath).readAsStringSync();

    expect(
      main,
      contains(
        "import '../features/employee/presentation/employee_platform_with_passport.dart';",
      ),
    );
    expect(main, contains('EmployeePlatformWithPassport(profile: profile)'));
    expect(wrapper, contains("storageKey: 'employee'"));
    expect(wrapper, contains("label: 'Команда'"));
    expect(wrapper, contains('EmployeeTeamTabScreen'));
    expect(wrapper, contains('builder: (_)'));
    expect(wrapper, isNot(contains('CupertinoPageRoute')));
    expect(wrapper, isNot(contains('EmployeeCommunityHubScreen')));
    expect(wrapper, contains('legacy.EmployeeMainScreen'));
    expect(override, contains('final WidgetBuilder? builder'));
    expect(navigation, contains('PlatformTabOverrideScope.resolve('));
    expect(navigation, contains('override?.label ?? baseItem.label'));
    expect(navigation, contains('unawaited(handleSelected(index))'));
    expect(shell, contains('override?.builder?.call(context)'));
  });

  test('экран показывает фундамент будущего сообщества', () {
    final screen = File(screenPath).readAsStringSync();

    for (final section in <String>[
      'Паспорт специалиста',
      'Подтверждено работой',
      'О специалисте',
      'Навыки',
      'Готовность к работе',
      'Достижения',
      'Профессиональное резюме',
      'Аккаунт сотрудника',
    ]) {
      expect(screen, contains(section));
    }
    expect(screen, contains('LinearProgressIndicator'));
    expect(screen, contains('Clipboard.setData'));
    expect(screen, contains('Подтверждено AppСтрой'));
    expect(screen, contains('Открыт к предложениям'));
    expect(screen, contains('Готов к вахте'));
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

  test('копируемое резюме не содержит личный телефон и расчёты', () {
    final screen = File(screenPath).readAsStringSync();
    final start = screen.indexOf('String _resumeText(');
    final end = screen.indexOf('String _formatMoney(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final resume = screen.substring(start, end);

    expect(resume, contains('Подтверждено в AppСтрой'));
    expect(resume, contains('verified.totalShifts'));
    expect(resume, contains('verified.completedTasks'));
    expect(resume, isNot(contains('profile.phone')));
    expect(resume, isNot(contains('phone')));
    expect(resume, isNot(contains('payments')));
    expect(resume, isNot(contains('paid')));
    expect(resume, isNot(contains('comment')));
  });

  test('редактирование не пишет в базу напрямую из интерфейса', () {
    final screen = File(screenPath).readAsStringSync();

    expect(screen, contains('EmployeeProfessionalProfileRepository.save('));
    expect(screen, isNot(contains("functions.invoke('")));
    expect(screen, isNot(contains(".from('")));
    expect(screen, isNot(contains('.insert(')));
    expect(screen, isNot(contains('.upsert(')));
    expect(screen, isNot(contains('.update(')));
  });
}
