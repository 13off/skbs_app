import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kanban supports inline stage creation and renaming', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Widget addColumnTile('));
    expect(source, contains("'Добавить колонку'"));
    expect(source, contains('Future<void> createStage('));
    expect(source, contains('Future<void> renameStage('));
    expect(source, contains("tooltip: 'Переименовать колонку'"));
    expect(source, contains('RecruitmentRepository.savePipelineStage('));
  });

  test('kanban drag uses optimistic stage and smooth feedback', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();

    expect(source, contains('pendingStageIds[application.id] = stage.id'));
    expect(source, contains('effectiveStageFor(application, configuration)'));
    expect(source, contains('rootOverlay: true'));
    expect(source, contains('AnimatedScale('));
    expect(source, contains('Curves.easeOutCubic'));
  });

  test('automation editor reloads live board stages', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_automation_settings_panel.dart',
    ).readAsStringSync();

    expect(source, contains('RecruitmentRepository.fetchConfiguration('));
    expect(source, contains('includeInactive: false'));
    expect(source, contains('stages: stages'));
    expect(source, contains('data.configuration.stageById'));
    expect(source, isNot(contains('stages: widget.configuration.stages')));
  });
}
