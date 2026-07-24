import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Защищает единый сценарий управления колонками CRM на доске и в настройках.
// Полный прогон подтверждает совместимость с существующими экранами AppСтрой.
void main() {
  test('new CRM columns are created atomically at the right edge', () {
    final board = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/recruitment/data/recruitment_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260724180000_fix_recruitment_column_order.sql',
    ).readAsStringSync();

    expect(board, contains('createPipelineStageAtEnd('));
    expect(board, contains('добавлена справа'));
    expect(settings, contains('createPipelineStageAtEnd('));
    expect(repository, contains("'create_recruitment_pipeline_stage_at_end'"));
    expect(migration, contains('pg_advisory_xact_lock'));
    expect(migration, contains('coalesce(max(stage.sort_order), 0) + 10'));
  });

  test('column drag persists the exact server-confirmed order', () {
    final board = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/recruitment/data/recruitment_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260724180000_fix_recruitment_column_order.sql',
    ).readAsStringSync();

    expect(board, contains('Draggable<RecruitmentPipelineStage>'));
    expect(board, contains('LongPressDraggable<RecruitmentPipelineStage>'));
    expect(board, contains('final confirmedIds ='));
    expect(board, contains('Сервер сохранил другой порядок колонок'));
    expect(board, isNot(contains('placeAfter:')));
    expect(settings, contains('ReorderableListView.builder'));
    expect(repository, contains("'reorder_recruitment_pipeline_stages_v2'"));
    expect(migration, contains('reorder_recruitment_pipeline_stages_v2'));
    expect(migration, contains('revoke all on function'));
  });

  test('column deletion safely moves candidates and removes the stage', () {
    final board = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/recruitment/data/recruitment_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260724145000_recruitment_stage_delete.sql',
    ).readAsStringSync();

    expect(board, contains("'Удалить колонку'"));
    expect(settings, contains("'Удалить колонку'"));
    expect(repository, contains('deletePipelineStage('));
    expect(repository, contains("'delete_recruitment_pipeline_stage'"));
    expect(migration, contains('security definer'));
    expect(migration, contains('update public.recruitment_applications'));
    expect(migration, contains('delete from public.recruitment_pipeline_stages'));
    expect(migration, contains('recruitment.crm.configure'));
  });
}
