import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('new and existing tasks expose optional goal linking', () {
    final create = source('lib/screens/add_task_screen.dart');
    final details =
        source('lib/screens/task_details_screen.dart') +
        source('lib/screens/task_details_legacy_screen.dart');
    final picker = source(
      'lib/features/milestones/presentation/task_milestone_picker.dart',
    );

    expect(create, contains('TaskMilestonePicker('));
    expect(create, contains("milestoneId: selectedMilestoneId ?? ''"));
    expect(details, contains('TaskRepository.fetchTaskMilestoneLink'));
    expect(details, contains('TaskMilestonePicker('));
    expect(details, contains('TaskProgressRepository.fetchContext'));
    expect(picker, contains("'Тип задачи'"));
    expect(picker, contains("child: Text('Обычная задача')"));
    expect(picker, contains("child: Text('По цели')"));
    expect(picker, contains('final bool goalMode;'));
  });

  test('goal task selects exactly one goal work without extra controls', () {
    final create = source('lib/screens/add_task_screen.dart');
    final details = source('lib/screens/task_details_legacy_screen.dart');
    final picker = source(
      'lib/features/milestones/presentation/task_milestone_picker.dart',
    );

    expect(picker, contains("labelText: 'Цель'"));
    expect(picker, contains("labelText: 'Работа по цели'"));
    expect(picker, contains("hintText: 'Выберите одну работу'"));
    expect(picker, isNot(contains("const Text('Вес')")));
    expect(picker, isNot(contains("title: const Text('Критичный пункт')")));
    expect(picker, isNot(contains("label: const Text('Добавить пункт')")));
    expect(create, contains('selection.checklistTitle'));
    expect(create, contains('selection.goalMode'));
    expect(create, contains('final linkedToGoal = isGoalTask;'));
    expect(create, contains('savedWork'));
    expect(details, contains('selection.checklistTitle'));
    expect(details, contains('selection.goalMode'));
    expect(details, contains('if (!isGoalTask)'));
  });

  test('task repository persists link and supports explicit unlinking', () {
    final repository = source('lib/data/task_repository.dart');
    final model = source('lib/models/task_item_data.dart');

    expect(repository, contains("from('task_milestone_links')"));
    expect(repository, contains('fetchTaskMilestoneLink'));
    expect(repository, contains('saveTaskMilestoneLink'));
    expect(
      repository,
      contains("from('task_milestone_links').delete().eq('task_id', taskId)"),
    );
    expect(model, contains('final String? milestoneId;'));
    expect(model, contains('final String? checklistItemId;'));
  });
}
