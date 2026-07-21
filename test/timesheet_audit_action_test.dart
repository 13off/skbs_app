import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/data/ai_assistant_repository.dart';

import 'support/ai_operational_source.dart';

void main() {
  test('вопросы о расхождениях табеля идут в read only проверку', () {
    for (final prompt in const <String>[
      'Покажи расхождения табеля за июль',
      'Проверь ошибки в табеле за июнь',
      'У кого нет смен за май',
      'Есть ли пустые записи табеля за апрель',
    ]) {
      expect(
        AiAssistantRepository.functionNameFor(mode: 'chat', prompt: prompt),
        'ai-operational-draft',
        reason: prompt,
      );
    }
  });

  test('сервер проверяет только измеримые несоответствия', () {
    final source = aiOperationalSource();

    expect(source, contains('find_timesheet_gaps'));
    expect(source, contains('.from("attendance")'));
    expect(source, contains('.eq("company_id", companyId)'));
    expect(source, contains('status === "worked"'));
    expect(source, contains('status === "no_show"'));
    expect(source, contains('shifts < 0 || shifts > 3'));
    expect(source, contains('не подтверждённая ошибка'));
    expect(source, contains('приложение не знает плановый график'));
    expect(source, contains('type: "open_period_timesheet"'));
    expect(source, isNot(contains('.insert(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.upsert(')));
    expect(source, isNot(contains('.delete(')));
  });

  test('проверка открывает штатный месячный табель на выбранном периоде', () {
    final coordinator = File(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    ).readAsStringSync();
    final confirmation = File(
      'lib/features/ai/presentation/ai_action_confirmation_sheet.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/screens/period_timesheet_screen.dart',
    ).readAsStringSync();

    expect(coordinator, contains("'open_period_timesheet'"));
    expect(coordinator, contains('PeriodTimesheetScreen('));
    expect(confirmation, contains('PeriodTimesheetLaunchIntent.setFromYearMonth'));
    expect(screen, contains('PeriodTimesheetLaunchIntent.take()'));
    expect(screen, contains('widget.initialMonth'));
  });
}
