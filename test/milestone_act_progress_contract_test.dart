import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('foreman can edit checklist names and delete checklist items or goals', () {
    final detail = source(
      'lib/features/milestones/presentation/milestone_detail_screen.dart',
    );
    final repository = source(
      'lib/features/milestones/data/milestone_repository.dart',
    );
    final migration = source(
      'supabase/migrations/20260717090000_allow_foreman_delete_milestones.sql',
    );

    expect(detail, contains('Изменить пункт чек-листа'));
    expect(detail, contains('MilestoneRepository.updateChecklistItem'));
    expect(detail, contains('MilestoneRepository.deleteChecklistItem'));
    expect(detail, contains('widget.profile.isAdmin || widget.profile.isForeman'));
    expect(repository, contains('deleteMilestone'));
    expect(migration, contains('is_foreman() and can_access_object(object_name)'));
  });

  test('completed-work act includes goal and checklist percentages', () {
    final preview = source('lib/screens/act_preview_screen.dart');
    final generator = source('lib/data/act_generator.dart');
    final contextRepository = source('lib/data/act_context_repository.dart');

    expect(preview, contains('ActContextRepository.fetchForTasks'));
    expect(preview, contains('Пункт чек-листа:'));
    expect(preview, contains('milestoneProgressPercent'));
    expect(generator, contains('Готовность цели'));
    expect(generator, contains('checklistProgressPercent'));
    expect(contextRepository, contains("from('task_milestone_links')"));
    expect(contextRepository, contains('MilestoneRepository.fetchMilestones'));
  });
}
