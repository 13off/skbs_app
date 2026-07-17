import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('milestones use weighted checklist and linked tasks', () {
    final models = source(
      'lib/features/milestones/models/milestone_models.dart',
    );
    final repository = source(
      'lib/features/milestones/data/milestone_repository.dart',
    );

    expect(models, contains('item.weight * item.completionFraction'));
    expect(models, contains("state == 'blocked'"));
    expect(models, contains('tasks.isNotEmpty && doneTaskCount == tasks.length'));
    expect(models, contains('blockingItems'));
    expect(repository, contains("from('project_milestones')"));
    expect(repository, contains("from('milestone_checklist_items')"));
    expect(repository, contains("from('task_milestone_links')"));
    expect(repository, contains('concreteChecklist'));
  });

  test('milestone detail creates a normal task and links it to checklist', () {
    final detail = source(
      'lib/features/milestones/presentation/milestone_detail_screen.dart',
    );

    expect(detail, contains('AddTaskScreen('));
    expect(detail, contains('TaskRepository.addTaskWithDetails'));
    expect(detail, contains('MilestoneRepository.linkTask'));
    expect(detail, contains('Добавить задачу к этому пункту'));
    expect(detail, contains('Критичный пункт'));
  });

  test('main screens show nearest milestone without replacing navigation', () {
    final overlay = source(
      'lib/features/milestones/presentation/milestone_home_overlay.dart',
    );
    final foreman = source(
      'lib/features/foreman/presentation/foreman_main_screen.dart',
    );
    final adaptiveHome = source('lib/screens/adaptive_home_screen.dart');

    expect(overlay, contains('MilestoneRepository.fetchNearest'));
    expect(overlay, contains('LinearProgressIndicator'));
    expect(foreman, contains('MilestoneHomeOverlay'));
    expect(foreman, contains('ProfessionalBottomNavigation'));
    expect(adaptiveHome, contains('MilestoneHomeOverlay'));
  });
}
