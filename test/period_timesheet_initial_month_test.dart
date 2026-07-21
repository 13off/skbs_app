import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/screens/period_timesheet/period_timesheet_launch_intent.dart';

void main() {
  tearDown(PeriodTimesheetLaunchIntent.clear);

  test('year-month parser accepts valid month and normalizes first day', () {
    expect(
      PeriodTimesheetLaunchIntent.parseYearMonth('2026-07'),
      DateTime(2026, 7, 1),
    );
    expect(PeriodTimesheetLaunchIntent.parseYearMonth('2026-13'), isNull);
    expect(PeriodTimesheetLaunchIntent.parseYearMonth('июль 2026'), isNull);
  });

  test('launch intent is consumed exactly once', () {
    expect(PeriodTimesheetLaunchIntent.setFromYearMonth('2026-07'), isTrue);
    expect(PeriodTimesheetLaunchIntent.take(), DateTime(2026, 7, 1));
    expect(PeriodTimesheetLaunchIntent.take(), isNull);
  });

  test('AI confirmation passes month and screen consumes it', () {
    final confirmation = File(
      'lib/features/ai/presentation/ai_action_confirmation_sheet.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/screens/period_timesheet_screen.dart',
    ).readAsStringSync();

    expect(
      confirmation,
      contains("PeriodTimesheetLaunchIntent.setFromYearMonth(action.text('month'))"),
    );
    expect(screen, contains('final pendingMonth = PeriodTimesheetLaunchIntent.take()'));
    expect(screen, contains('final requestedMonth = widget.initialMonth ?? pendingMonth'));
    expect(screen, contains('selectedMonth = DateTime(base.year, base.month, 1)'));
  });
}
