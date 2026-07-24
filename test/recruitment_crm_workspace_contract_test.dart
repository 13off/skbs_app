import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full candidate CRM workspace is backed by company-scoped tables', () {
    final migration = File(
      'supabase/migrations/20260724073000_recruitment_crm_workspace.sql',
    ).readAsStringSync();

    for (final table in <String>[
      'recruitment_crm_comments',
      'recruitment_crm_tasks',
      'recruitment_crm_activities',
      'recruitment_crm_saved_views',
      'recruitment_crm_automation_rules',
      'recruitment_crm_automation_runs',
    ]) {
      expect(migration, contains('public.$table'));
      expect(
        migration,
        contains('alter table public.$table enable row level security'),
      );
    }
    expect(migration, contains('responsible_user_id'));
    expect(migration, contains('assign_recruitment_responsible'));
    expect(migration, contains('bulk_move_recruitment_applications'));
    expect(migration, contains('scheduled_reminders'));
    expect(migration, contains('validate_recruitment_crm_task_assignee'));
  });

  test('candidate card exposes comments tasks timeline and responsible HR', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_candidate_crm_section.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart',
    ).readAsStringSync();

    expect(detail, contains('RecruitmentCandidateCrmSection'));
    expect(source, contains('Ответственный HR'));
    expect(source, contains('Дела и напоминания'));
    expect(source, contains('Комментарии HR'));
    expect(source, contains('Лента событий'));
    expect(source, contains('addComment'));
    expect(source, contains('saveTask'));
    expect(source, contains('setTaskStatus'));
  });

  test(
    'kanban supports saved views mass actions responsible and overdue data',
    () {
      final source = File(
        'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
      ).readAsStringSync();

      expect(source, contains('RecruitmentBoardSupportData'));
      expect(source, contains('Сохранить текущий вид'));
      expect(source, contains('Массовые действия'));
      expect(source, contains('assignSelected'));
      expect(source, contains('bulkMove'));
      expect(source, contains('hideEmptyColumns'));
      expect(source, contains('indicator.overdueTasks'));
    },
  );
}
