import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void expectFragments(
  String label,
  String contents,
  Iterable<String> fragments,
) {
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Критичный маршрут или действие "$fragment" исчезло из $label',
    );
  }
}

void main() {
  test('главная оболочка сохраняет рабочие платформы и вкладки', () {
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expectFragments('главной оболочки', shell, const <String>[
      "label: 'Главная'",
      "label: 'Люди'",
      "label: 'Табель'",
      "label: 'Задачи'",
      "label: 'Профиль'",
      'AdaptiveEmployeesScreen(',
      'TimesheetScreen(',
      'TasksScreen(',
      'ProfileScreen(',
    ]);
  });

  test('главная сохраняет объект, отчёты и ИИ-помощника', () {
    final home = <String>[
      'lib/screens/home_screen.dart',
      'lib/screens/home/home_actions.dart',
      'lib/screens/home/home_object_actions.dart',
      'lib/screens/home/home_sections.dart',
      'lib/screens/home/home_view.dart',
      'lib/screens/home/home_widgets.dart',
    ].map(source).join('\n');

    expectFragments('главной', home, const <String>[
      'onObjectChanged',
      'AiAssistantScreen(',
      "tooltip: 'ИИ-помощник'",
      "'Архив объектов'",
      "'Архивировать объект'",
    ]);
  });

  test('сотрудники сохраняют добавление, карточку, выплаты и сводку', () {
    final employees = <String>[
      'lib/screens/employees_screen.dart',
      'lib/screens/employees/employees_actions.dart',
      'lib/screens/employees/employees_view.dart',
      'lib/screens/employee_details_screen.dart',
      'lib/screens/employee_details/employee_details_view.dart',
    ].map(source).join('\n');

    expectFragments('сотрудников', employees, const <String>[
      'AddEmployeeScreen(',
      'EmployeeDetailsScreen(',
      'PaymentsScreen(',
      'downloadSummary()',
      "title: 'Личные данные'",
      "title: 'Документы'",
      "title: 'Выплаты'",
    ]);
  });

  test('табель сохраняет ввод, сохранение и месячный отчёт', () {
    final timesheet = <String>[
      'lib/screens/timesheet_screen.dart',
      'lib/screens/timesheet/timesheet_actions.dart',
      'lib/screens/timesheet/timesheet_view.dart',
      'lib/screens/period_timesheet_screen.dart',
      'lib/screens/period_timesheet/period_timesheet_export.dart',
      'lib/screens/period_timesheet/period_timesheet_view.dart',
    ].map(source).join('\n');

    expectFragments('табеля', timesheet, const <String>[
      'AttendanceRepository.saveTimesheet',
      "'Сохранить табель'",
      'PeriodTimesheetScreen(',
      "'Скачать Excel'",
    ]);
  });

  test('задачи сохраняют создание, редактирование и акт', () {
    final tasks = <String>[
      'lib/screens/tasks_screen.dart',
      'lib/screens/add_task_screen.dart',
      'lib/screens/task_create/task_create_view.dart',
      'lib/screens/task_details/task_details_editor_screen.dart',
      'lib/screens/act_preview_screen.dart',
    ].map(source).join('\n');

    expectFragments('задач', tasks, const <String>[
      'AddTaskScreen(',
      'TaskDetailsScreen(',
      "'Сохранить задачу'",
      "'Сформировать акт'",
      "'Скачать акт'",
    ]);
  });

  test('профиль сохраняет управление компанией, архив и системные разделы', () {
    final profile = source('lib/screens/profile_screen.dart');

    expectFragments('профиля', profile, const <String>[
      'RolePreviewScreen(',
      'NotificationControlCenterScreen(',
      'CompanyManagementScreen(',
      'ArchiveManagementScreenV3(',
      'TemplateDocumentsScreen(',
      'CompanySwitcherScreen(',
      'UserRepository.signOut()',
    ]);
  });

  test('ограничения объектов остаются подключены к созданию задач', () {
    final taskLoading = source(
      'lib/screens/task_create/task_create_loading.dart',
    );
    final policyRepository = source(
      'lib/features/developer/data/developer_policy_repository.dart',
    );

    expect(taskLoading, contains('DeveloperPolicyRepository.ensurePolicy'));
    expectFragments('репозитория ограничений', policyRepository, const <String>[
      "'get_effective_task_policy'",
      "'get_developer_task_policy_center'",
      "'save_task_policy_setting'",
      "'reset_task_policy_override'",
    ]);
  });
}
