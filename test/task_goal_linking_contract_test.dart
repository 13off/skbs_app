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
    expect(picker, contains("labelText: 'Привязать к цели'"));
    expect(picker, contains("child: Text('Не привязано')"));
  });

  test('selected goal immediately shows an editable checklist', () {
    final picker = source(
      'lib/features/milestones/presentation/task_milestone_picker.dart',
    );
    final milestones = source(
      'lib/features/milestones/data/milestone_repository.dart',
    );

    expect(picker, contains("'Чек-лист цели'"));
    expect(picker, contains("label: const Text('Добавить пункт')"));
    expect(picker, contains("tooltip: 'Изменить пункт'"));
    expect(picker, contains("tooltip: 'Удалить пункт'"));
    expect(picker, contains('MilestoneRepository.updateChecklistState'));
    expect(milestones, contains('updateChecklistItem({'));
    expect(milestones, contains('deleteChecklistItem(String itemId)'));
  });

  test('task repository persists link and supports explicit unlinking', () {
    final repository = source('lib/data/task_repository.dart');
    final model = source('lib/models/task_item_data.dart');

    expect(repository, contains("from('task_milestone_links')"));
    expect(repository, contains('fetchTaskMilestoneLink'));
    expect(repository, contains('saveTaskMilestoneLink'));
    expect(repository, contains(".delete()\n          .eq('task_id', taskId)"));
    expect(model, contains('final String? milestoneId;'));
    expect(model, contains('final String? checklistItemId;'));
  });
}
