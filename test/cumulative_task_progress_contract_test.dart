import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('completed daily tasks accumulate exact checklist progress', () {
    final repository = source('lib/data/task_progress_repository.dart');
    final model = source(
      'lib/features/milestones/models/milestone_models.dart',
    );
    final migration = source(
      'supabase/migrations/20260717110000_add_task_progress_percent.sql',
    );

    expect(repository, contains(".select('task_id, progress_percent, tasks(status)')"));
    expect(repository, contains("nextState = 'progress_\$total'"));
    expect(repository, contains('maxAllowedPercent'));
    expect(model, contains("RegExp(r'^progress_(\\d{1,3})\$')"));
    expect(model, contains('completionFraction => progressPercent / 100'));
    expect(migration, contains('progress_percent integer not null default 0'));
    expect(migration, contains('progress_percent between 0 and 100'));
  });

  test('task completion asks for todays contribution and protects remainder', () {
    final details = source('lib/screens/task_details_screen.dart');
    final legacy = source('lib/screens/task_details_legacy_screen.dart');

    expect(details, contains('Что выполнили сегодня?'));
    expect(details, contains('Максимум для этой задачи'));
    expect(details, contains('ownProgressIsCounted'));
    expect(details, contains('Сохранить выполнение'));
    expect(details, contains('legacy.TaskDetailsScreen'));
    expect(legacy, contains('Фото'));
    expect(legacy, contains('Исполнители'));
    expect(legacy, contains('TaskMilestonePicker'));
  });

  test('act contains daily, checklist and goal percentages', () {
    final context = source('lib/models/task_act_context.dart');
    final contextRepository = source('lib/data/act_context_repository.dart');
    final preview = source('lib/screens/act_preview_screen.dart');
    final generator = source('lib/data/act_generator.dart');

    expect(context, contains('taskProgressPercent'));
    expect(contextRepository, contains('progress_percent'));
    expect(contextRepository, contains('за день +\$dailyPercent%'));
    expect(preview, contains('Выполнение за день: +'));
    expect(generator, contains('checklistStateTitle.toLowerCase()'));
  });
}
