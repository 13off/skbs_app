import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ticket-purchased card move opens a preselected flight editor', () {
    final recruitmentRepository = File(
      'lib/features/recruitment/data/recruitment_repository.dart',
    ).readAsStringSync();
    final flightRepository = File(
      'lib/features/recruitment/data/recruitment_flight_repository.dart',
    ).readAsStringSync();
    final recruitmentMain = File(
      'lib/features/recruitment/presentation/recruitment_main_screen.dart',
    ).readAsStringSync();
    final flightCalendar = File(
      'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart',
    ).readAsStringSync();

    expect(recruitmentRepository, contains('RecruitmentApplicationStageMove'));
    expect(recruitmentRepository, contains('_stageMoveController.add'));
    expect(recruitmentMain, contains('RecruitmentRepository.stageMoves.listen'));
    expect(
      recruitmentMain,
      contains('RecruitmentFlightRepository.isTicketPurchasedStage'),
    );
    expect(recruitmentMain, contains('RecruitmentFlightEditorScreen'));
    expect(recruitmentMain, contains('candidates: [selected]'));

    expect(flightRepository, contains("title == 'куплен билет'"));
    expect(flightRepository, contains(".inFilter('stage_id', stageIds)"));
    expect(flightRepository, contains('_fetchAllCandidates'));
    expect(
      flightCalendar,
      contains(
        'widget.candidates.length == 1 ? widget.candidates.first : null',
      ),
    );
    expect(flightCalendar, contains('entry.candidate, ...data.candidates'));
  });
}
