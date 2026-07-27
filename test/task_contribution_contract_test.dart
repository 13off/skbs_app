// Контракт также служит безопасным триггером публикации Web/PWA.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed task asks for one exact 100 percent contribution split', () {
    final wrapper = File(
      'lib/screens/task_details_screen.dart',
    ).readAsStringSync();
    final dialog = File(
      'lib/features/tasks/presentation/task_contribution_dialog.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/task_contribution_repository.dart',
    ).readAsStringSync();

    expect(wrapper, contains('TaskContributionRepository.fetchDraft'));
    expect(wrapper, contains('showTaskContributionDialog'));
    expect(wrapper, contains('hasSavedExactDistribution'));
    expect(wrapper, contains('добавьте хотя бы одного участника'));
    expect(wrapper, contains('TaskContributionRepository.clear'));
    expect(dialog, contains("title: const Text('Вклад в результат')"));
    expect(dialog, contains("'Всего: \$total%'"));
    expect(dialog, contains("label: const Text('Поровну')"));
    expect(repository, contains('static List<int> equalPercents'));
    expect(repository, contains("'save_task_contributions'"));
  });

  test('server validates tenant task participants and exact total', () {
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
