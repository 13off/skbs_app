import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String planner;
  late String index;

  setUpAll(() {
    planner = File(
      'supabase/functions/ai-global-command/multi_step_plan_v15.ts',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  test(
    'v15 выполняется после action trace и до ссылочных и одиночных роутеров',
    () {
      expect(index, contains('buildMultiStepVoicePlan'));
      final trace = index.indexOf('buildActionTraceFollowUp({');
      final plan = index.indexOf('buildMultiStepVoicePlan({');
      final group = index.indexOf('buildGroupReferencedFollowUp({');
      final single = index.indexOf('candidateResponsibleIntent(prompt)');
      expect(trace, greaterThanOrEqualTo(0));
      expect(plan, greaterThan(trace));
      expect(group, greaterThan(plan));
      expect(single, greaterThan(plan));
    },
  );

  test('planner только читает данные и не пишет таблицы напрямую', () {
    expect(planner, isNot(contains('.insert(')));
    expect(planner, isNot(contains('.update(')));
    expect(planner, isNot(contains('.delete(')));
    expect(planner, contains('confirmation_required: true'));
    expect(planner, contains('resultWithAction({'));
    expect(planner, contains('voice_compound_batch'));
  });

  test(
    'табель строится по employees плюс attendance и сохраняет объект прораба',
    () {
      expect(planner, contains('.from("employees")'));
      expect(planner, contains('.from("attendance")'));
      expect(planner, contains('.eq("work_date", date)'));
      expect(planner, contains('role === "foreman"'));
      expect(planner, contains('assignedObject'));
      expect(planner, contains('prepare_timesheet_correction'));
      expect(planner, contains('shiftValue(prompt)'));
      expect(planner, contains('voice_multi_step_plan_v15'));
    },
  );

  test(
    'табель понимает отсутствие присутствие и должность внутри найденной группы',
    () {
      expect(planner, contains('не\\s+выш'));
      expect(planner, contains('не\\s+явил'));
      expect(planner, contains('присутств'));
      expect(planner, contains('row.position'));
      expect(planner, contains('mentionedPositions'));
    },
  );

  test(
    'HR умеет фильтровать отсутствие ответственного и неполный комплект',
    () {
      expect(planner, contains('responsible_user_id'));
      expect(planner, contains('wantsNoResponsible'));
      expect(planner, contains('wantsIncompleteDocs'));
      expect(planner, contains('passport_main'));
      expect(planner, contains('registration'));
      expect(planner, contains('snils'));
      expect(planner, contains('inn'));
      expect(planner, contains('policy'));
      expect(planner, contains('.from("recruitment_documents")'));
    },
  );

  test('HR умеет искать ожидающих ответа и кандидатов с вылетом на дату', () {
    expect(planner, contains('.from("recruitment_messages")'));
    expect(planner, contains('latestInbound'));
    expect(planner, contains('latestOutbound'));
    expect(planner, contains('.from("recruitment_flights")'));
    expect(planner, contains('.gte("departure_at", start)'));
    expect(planner, contains('.neq("status", "cancelled")'));
  });

  test(
    'HR действия переиспользуют проверенные builders вместо прямых записей',
    () {
      expect(planner, contains('buildCandidateResponsible({'));
      expect(planner, contains('buildHrStageMove({'));
      expect(planner, contains('send_candidate_message'));
      expect(planner, contains('canMessageCandidate'));
      expect(planner, contains('telegram'));
      expect(planner, contains('max'));
    },
  );

  test('снабжение фильтруется по сроку приоритету статусу и объекту', () {
    expect(planner, contains('.from("procurement_requests")'));
    expect(planner, contains('needed_by'));
    expect(planner, contains('priority === "urgent"'));
    expect(planner, contains('procurementSelectorStatus'));
    expect(planner, contains('buildProcurementStatus({'));
    expect(planner, contains('requestedObject'));
  });

  test('выбор поддерживает первые последние явные позиции и исключения', () {
    expect(planner, contains('ordinalIndexes'));
    expect(planner, contains('ordinalAfter(words, "кроме")'));
    expect(planner, contains('word.startsWith("перв")'));
    expect(planner, contains('word.startsWith("последн")'));
    expect(planner, contains('new Set(ordinals.map'));
  });

  test('массовое действие ограничено двенадцатью целями', () {
    expect(planner, contains('const maxPlannedWrites = 12'));
    expect(planner, contains('максимум \${maxPlannedWrites}'));
  });

  test(
    'параметры плана не содержат entity ids и остаются диагностическими',
    () {
      expect(planner, contains('source: "deterministic_tool_planner"'));
      expect(planner, contains('matched_count: matchedCount'));
      expect(planner, contains('selected_count: selectedCount'));
      final planStart = planner.indexOf('plan: {');
      final planEnd = planner.indexOf('\n    },\n  };', planStart);
      expect(planStart, greaterThanOrEqualTo(0));
      expect(planEnd, greaterThan(planStart));
      final metadata = planner.substring(planStart, planEnd);
      expect(metadata, isNot(contains('employee_id')));
      expect(metadata, isNot(contains('application_id')));
      expect(metadata, isNot(contains('request_id')));
    },
  );

  test(
    'planner сначала отделяет selector от action чтобы не путать целевой статус с фильтром',
    () {
      expect(planner, contains('selectorClause'));
      expect(planner, contains('actionMarkerIndex'));
      expect(
        planner,
        contains('const selector = selectorClause(prompt, "candidates")'),
      );
      expect(
        planner,
        contains('const selector = selectorClause(prompt, "procurement")'),
      );
    },
  );
}
