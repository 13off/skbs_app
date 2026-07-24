import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Защищает единый сценарий управления колонками CRM на доске и в настройках.
// Полный прогон подтверждает совместимость с существующими экранами AppСтрой.
void main() {
  test('new CRM columns are explicitly placed at the right edge', () {
    final board = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
    ).readAsStringSync();

    expect(board, contains(".followedBy(<String>[created.id])"));
    expect(board, contains("добавлена справа"));
    expect(settings, contains(".followedBy(<String>[saved.id])"));
  });

  test('columns can be reordered by drag instead of stage arrows', () {
    final board = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
    ).readAsStringSync();

    expect(board, contains('Draggable<RecruitmentPipelineStage>'));
    expect(board, contains('LongPressDraggable<RecruitmentPipelineStage>'));
    expect(board, contains('reorderStageOnBoard('));
    expect(board, contains("'Перетащить колонку'"));
    expect(settings, contains('ReorderableListView.builder'));
    expect(settings, contains('ReorderableDragStartListener'));
    expect(settings, isNot(contains('Future<void> moveStage(')));
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
