import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('milestones keep linked task progress internally', () {
    final models = source(
      'lib/features/milestones/models/milestone_models.dart',
    );
    final repository = source(
      'lib/features/milestones/data/milestone_repository.dart',
    );

    expect(models, contains('item.weight * item.completionFraction'));
    expect(
      models,
      contains('tasks.isNotEmpty && doneTaskCount == tasks.length'),
    );
    expect(repository, contains("from('project_milestones')"));
    expect(repository, contains("from('milestone_checklist_items')"));
    expect(repository, contains("from('task_milestone_links')"));
  });

  test('goal checklist UI asks only for one work name', () {
    final detail = source(
      'lib/features/milestones/presentation/milestone_detail_screen.dart',
    );

    expect(detail, contains('AddTaskScreen('));
    expect(detail, contains('TaskRepository.addTaskWithDetails'));
    expect(detail, contains("hintText: 'Армирование'"));
    expect(detail, contains("child: Text('Изменить название')"));
    expect(detail, isNot(contains('Критичный пункт')));
    expect(detail, isNot(contains("const Text('Вес')")));
  });

  test('main screens show several goals inline before metrics', () {
    final section = source(
      'lib/features/milestones/presentation/milestone_home_overlay.dart',
    );
    final home = source('lib/screens/home_screen.dart');
    final adaptive = source('lib/screens/adaptive_home_screen.dart');
    final desktop = source('lib/screens/adaptive_home_base_screen.dart');
    final foremanHome = source(
      'lib/features/foreman/presentation/foreman_desktop_home_screen.dart',
    );

    expect(section, contains('class MilestoneHomeSection'));
    expect(section, contains('MilestoneRepository.fetchMilestones'));
    expect(section, contains('active.take(4)'));
    expect(section, isNot(contains('Positioned(')));
    expect(home, contains('MilestoneHomeSection('));
    expect(home, contains("title: 'Выполненные задачи'"));
    expect(desktop, contains('MilestoneHomeSection('));
    expect(foremanHome, contains('MilestoneHomeSection('));
    expect(adaptive, isNot(contains('MilestoneHomeOverlay')));
  });
}
