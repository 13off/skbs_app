import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/timesheet/models/timesheet_absence_reason.dart';
import 'package:skbs_app/features/timesheet/models/timesheet_draft.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('причины невыхода имеют фиксированные коды и подписи', () {
    expect(TimesheetAbsenceReason.values, <String>['sick', 'day_off', 'no_show']);
    expect(TimesheetAbsenceReason.labelFor('sick'), 'Болезнь');
    expect(TimesheetAbsenceReason.labelFor('day_off'), 'Выходной');
    expect(TimesheetAbsenceReason.labelFor('no_show'), 'Прогул');
  });

  test('положительная смена очищает причину невыхода', () {
    final draft = TimesheetDraft.fromValues(
      const <String, double>{'employee': 0},
      absenceReasons: const <String, String>{'employee': 'sick'},
    );

    final worked = draft.withValue('employee', 1);

    expect(worked.valueFor('employee'), 1);
    expect(worked.absenceReasonFor('employee'), isNull);
    expect(worked.hasChanges, isTrue);
  });

  test('смена причины считается изменением табеля', () {
    final draft = TimesheetDraft.fromValues(
      const <String, double>{'employee': 0},
    );

    final absent = draft.withAbsenceReason('employee', 'day_off');

    expect(absent.absenceReasonFor('employee'), 'day_off');
    expect(absent.hasChanges, isTrue);
    expect(absent.markSaved().hasChanges, isFalse);
  });

  test('мобильный табель требует причину для нулевой смены', () {
    final actions = source('lib/screens/timesheet/timesheet_actions.dart');
    final sections = source('lib/screens/timesheet/timesheet_sections.dart');
    final view = source('lib/screens/timesheet/timesheet_view.dart');

    expect(actions, contains('missingAbsenceReasonEmployees'));
    expect(actions, contains('showAbsenceReasonPicker'));
    expect(actions, contains('Укажите причину невыхода'));
    expect(
      sections,
      contains('label: Text(TimesheetAbsenceReason.labelFor(reason))'),
    );
    expect(view, contains('buildMissingReasonsWarning(allEmployees)'));
  });

  test('широкий табель также сохраняет и требует причину невыхода', () {
    final desktop = source('lib/screens/desktop_timesheet_screen.dart');

    expect(
      desktop,
      contains('OfflineAttendanceReasonRepository.fetchReasonsForDate'),
    );
    expect(desktop, contains('OfflineAttendanceReasonRepository.saveReasons'));
    expect(desktop, contains('missingAbsenceReasonEmployees'));
    expect(desktop, contains("'Укажите причину невыхода:"));
    expect(desktop, contains('TimesheetAbsenceReason.values'));
    expect(desktop, contains("_HeaderText('Смена / причина')"));
  });

  test('причина едет через существующую offline attendance queue', () {
    final repository = source(
      'lib/data/offline_attendance_reason_repository.dart',
    );

    expect(repository, contains("kind: 'attendance.upsert'"));
    expect(repository, contains("'absence_reason': reason"));
    expect(repository, contains("'status': shifts > 0 ? 'worked' : 'no_show'"));
  });

  test('сервер отличает уважительные причины от прогула', () {
    final migration = source(
      'supabase/migrations/20260908111500_add_attendance_absence_reason.sql',
    );

    expect(migration, contains("('sick', 'day_off', 'no_show')"));
    expect(
      migration,
      contains(
        "coalesce(nullif(lower(btrim(a.absence_reason)), ''), 'no_show') = 'no_show'",
      ),
    );
    expect(migration, contains('update of\n  status,\n  shifts,\n  absence_reason'));
    expect(migration, contains("in ('sick', 'day_off')"));
  });

  test('объяснительная включает болезнь и прогул, но исключает выходной', () {
    final migration = source(
      'supabase/migrations/20260908181000_manager_absence_todos_include_sick.sql',
    );

    expect(migration, contains('v_explanation_items'));
    expect(
      migration,
      contains("lower(btrim(coalesce(attendance_row.absence_reason, ''))) = 'day_off'"),
    );
    expect(migration, contains('v_fine_items'));
    expect(
      migration,
      contains("lower(btrim(coalesce(attendance_row.absence_reason, ''))) = 'sick'"),
    );
    expect(
      migration,
      contains('Взять объяснительную у каждого сотрудника. Для прогулов оформить акт о нарушении.'),
    );
  });

  test('объяснительная появляется не раньше 10:00 МСК', () {
    final migration = source(
      'supabase/migrations/20260908172000_manager_absence_todos_10am.sql',
    );

    expect(migration, contains("time '10:00'"));
    expect(migration, isNot(contains("time '08:00'")));
    expect(migration, contains("'Взять объяснительные'"));
  });
}
