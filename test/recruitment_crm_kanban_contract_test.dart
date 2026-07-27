import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/recruitment/models/recruitment_models.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('candidate workspace is a real configurable kanban over existing applications', () {
    final screen = source(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    );
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );

    expect(screen, contains("title: 'Кандидаты'"));
    expect(screen, contains('RecruitmentViewMode.board'));
    expect(screen, contains('SegmentedButton<RecruitmentViewMode>'));
    expect(screen, contains('DragTarget<RecruitmentApplication>'));
    expect(screen, contains('Draggable<RecruitmentApplication>'));
    expect(screen, contains('LongPressDraggable<RecruitmentApplication>'));
    expect(screen, contains('kIsWeb'));
    expect(screen, contains('configuration.stages.expand'));
    expect(screen, contains('RecruitmentRepository.moveApplicationStage'));
    expect(screen, contains('objectFilter'));
    expect(screen, contains('vacancyFilter'));
    expect(screen, contains('searchController'));
    expect(screen, contains('openArchive'));
    expect(screen, contains('RecruitmentApplicationDetailScreen'));
    expect(screen, contains('RecruitmentCrmSettingsScreen'));

    expect(repository, contains(".from('recruitment_applications')"));
    expect(repository, contains(".from('recruitment_status_history')"));
    expect(repository, contains(".from('recruitment_pipeline_stages')"));
    expect(screen, isNot(contains(".from('recruitment_applications')")));
  });

  test('legacy stages remain deterministic for bots and existing automation', () {
    expect(recruitmentStageDefaultStatus('new'), 'new');
    expect(recruitmentStageDefaultStatus('documents'), 'waiting_documents');
    expect(recruitmentStageDefaultStatus('problems'), 'review');
    expect(recruitmentStageDefaultStatus('ready'), 'approved');
    expect(recruitmentStageDefaultStatus('tickets'), 'ticket_request');
    expect(recruitmentStageDefaultStatus('completed'), 'arrived');
    expect(recruitmentStageDefaultStatus('reserve'), 'reserve');
    expect(recruitmentStageDefaultStatus('rejected'), 'rejected');
  });

  test('HR bottom navigation names the CRM as candidates', () {
    final main = source(
      'lib/features/recruitment/presentation/recruitment_main_screen.dart',
    );

    expect(main, contains("label: 'Кандидаты'"));
    expect(main, contains('Icons.view_kanban_outlined'));
    expect(source('docs/recruitment-crm.md'), contains('recruitment_status_history'));
  });
}
