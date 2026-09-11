// Контракт также служит безопасным триггером публикации Web/PWA.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completion records actual volume and independent 0-200 KTU', () {
    final wrapper = File(
      'lib/screens/task_details_screen.dart',
    ).readAsStringSync();
    final dialog = File(
      'lib/features/tasks/presentation/task_contribution_dialog.dart',
    ).readAsStringSync();
    final workRepository = File(
      'lib/features/work_orders/work_order_repository.dart',
    ).readAsStringSync();

    expect(wrapper, contains('WorkOrderRepository.plan'));
    expect(wrapper, contains('showTaskContributionDialog'));
    expect(wrapper, contains('WorkOrderRepository.save'));
    expect(wrapper, contains("'ktu': entry.ktu"));
    expect(dialog, contains("labelText: 'Фактически выполненный объём'"));
    expect(dialog, contains("'КТУ исполнителей'"));
    expect(dialog, contains('this.ktu = 100'));
    expect(dialog, contains('max: 200'));
    expect(dialog, contains('divisions: 200'));
    expect(dialog, contains('changeKtu(index, value.round())'));
    expect(dialog, isNot(contains("'Всего: \$total%'")));
    expect(dialog, isNot(contains("label: const Text('Поровну')")));
    expect(dialog, isNot(contains('Распределите 100%')));
    expect(workRepository, contains("'м³', 'м²', 'т', 'шт.', 'м.п.'"));
  });

  test('task creation asks for compact plan before assignees', () {
    final view = File(
      'lib/screens/task_create/task_create_view.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/task_create/task_create_sections.dart',
    ).readAsStringSync();
    final workCard = File(
      'lib/features/work_orders/task_work_section.dart',
    ).readAsStringSync();

    final taskFields = view.indexOf('buildTaskFields()');
    final workPlan = view.indexOf('buildWorkPlanBlock()');
    final assignees = view.indexOf('buildAssigneesBlock()');
    expect(taskFields, greaterThanOrEqualTo(0));
    expect(workPlan, greaterThan(taskFields));
    expect(assignees, greaterThan(workPlan));

    expect(sections, contains("labelText: 'Количество'"));
    expect(sections, contains('DropdownButtonFormField<String>'));
    expect(sections, contains('WorkOrderRepository.unitOptions'));

    expect(workCard, contains("'Плановый объём задачи'"));
    expect(workCard, isNot(contains('Всего сохранено по дням')));
    expect(workCard, isNot(contains('Факт за')));
    expect(workCard, isNot(contains('Выполненный объём за этот день')));
    expect(workCard, isNot(contains('Сохранить объём и КТУ')));
  });

  test('server validates tenant task participants and exact legacy contribution total', () {
    final migration = File(
      'supabase/migrations/20260725100000_task_employee_contributions.sql',
    ).readAsStringSync();

    expect(migration, contains('enable row level security'));
    expect(
      migration,
      contains("current_user_has_object_permission('tasks.edit'"),
    );
    expect(migration, contains('v_total <> 100'));
    expect(migration, contains('every participant exactly once'));
    expect(migration, contains('contribution contains a non-participant'));
    expect(migration, contains('revoke all on table'));
    expect(migration, contains('from public, anon'));
    expect(migration, contains('to authenticated'));
  });

  test('employee card exposes contribution summary and task history', () {
    final employeeScreen = File(
      'lib/screens/employee_details_screen.dart',
    ).readAsStringSync();
    final employeeView = File(
      'lib/screens/employee_details/employee_details_view.dart',
    ).readAsStringSync();
    final employeeNavigation = File(
      'lib/screens/employee_details/employee_details_navigation.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/tasks/presentation/employee_contribution_screen.dart',
    ).readAsStringSync();

    expect(employeeScreen, contains('employee_contribution_screen.dart'));
    expect(employeeView, contains("title: 'Личный вклад'"));
    expect(employeeNavigation, contains('openContribution'));
    expect(summary, contains("_periodChip('Неделя'"));
    expect(summary, contains("_periodChip('Месяц'"));
    expect(summary, contains("_periodChip('Вахта'"));
    expect(summary, contains("_periodChip('Период'"));
    expect(summary, contains("title: 'Личный вклад'"));
    expect(summary, contains("title: 'Средняя доля'"));
    expect(summary, contains("title: 'Доля результата'"));
    expect(summary, contains("'История задач'"));
  });
}
