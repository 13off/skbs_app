import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String wrapper;
  late String goal;
  late String shared;
  late String candidate;
  late String operational;
  late String frozenV15;
  late String conversation;
  late String index;

  setUpAll(() {
    wrapper = File(
      'supabase/functions/ai-global-command/multi_step_plan.ts',
    ).readAsStringSync();
    goal = File(
      'supabase/functions/ai-global-command/goal_planner.ts',
    ).readAsStringSync();
    shared = File(
      'supabase/functions/ai-global-command/goal_planner_shared.ts',
    ).readAsStringSync();
    candidate = File(
      'supabase/functions/ai-global-command/goal_candidate_readiness.ts',
    ).readAsStringSync();
    operational = File(
      'supabase/functions/ai-global-command/goal_operational_risk.ts',
    ).readAsStringSync();
    frozenV15 = File(
      'supabase/functions/ai-global-command/multi_step_plan_v15.ts',
    ).readAsStringSync();
    conversation = File(
      'supabase/functions/ai-global-command/conversation_context.ts',
    ).readAsStringSync();
    index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();
  });

  test('v16 является добавочным слоем и оставляет v15 отдельным ядром', () {
    expect(wrapper, contains('buildGoalVoicePlan'));
    expect(wrapper, contains('buildV15MultiStepVoicePlan'));
    expect(wrapper, contains('multi_step_plan_v15.ts'));
    expect(wrapper.indexOf('buildGoalVoicePlan({'), lessThan(wrapper.indexOf('buildV15MultiStepVoicePlan({')));
    expect(frozenV15, contains('source: "deterministic_tool_planner"'));
    expect(frozenV15, contains('planner_version: 15'));
  });

  test('goal planner распознаёт цель а не только явный CRUD intent', () {
    expect(goal, contains('разберись'));
    expect(goal, contains('готовност'));
    expect(goal, contains('что\\s+горит'));
    expect(goal, contains('candidate_readiness'));
    expect(goal, contains('operational_risk'));
  });

  test('v16 goal modules не пишут таблицы напрямую', () {
    final all = '$goal\n$shared\n$candidate\n$operational';
    expect(all, isNot(contains('.insert(')));
    expect(all, isNot(contains('.update(')));
    expect(all, isNot(contains('.delete(')));
    expect(shared, contains('source: "deterministic_goal_planner"'));
    expect(shared, contains('version: 16'));
  });

  test('готовность кандидата соединяет рейс документы ответственного и связь', () {
    expect(candidate, contains('.from("recruitment_applications")'));
    expect(candidate, contains('.from("recruitment_flights")'));
    expect(candidate, contains('.from("recruitment_documents")'));
    expect(candidate, contains('.from("recruitment_messages")'));
    expect(candidate, contains('responsible_user_id'));
    expect(candidate, contains('passport_main'));
    expect(candidate, contains('registration'));
    expect(candidate, contains('snils'));
    expect(candidate, contains('inn'));
    expect(candidate, contains('policy'));
  });

  test('автоподготовка ограничена безопасными напоминаниями и подтверждением', () {
    expect(candidate, contains('hasCandidateChannel'));
    expect(candidate, contains('telegram'));
    expect(candidate, contains('max'));
    expect(candidate, contains('send_candidate_message'));
    expect(candidate, contains('confirmation_required: true'));
    expect(candidate, contains('missingDocs.length > 0 && item.hasChannel'));
    expect(shared, contains('export const maxGoalWrites = 12'));
    expect(candidate, contains('messageTargets.length > maxGoalWrites'));
  });

  test('операционная готовность объединяет табель задачи снабжение и входящий HR', () {
    expect(operational, contains('.from("employees")'));
    expect(operational, contains('.from("attendance")'));
    expect(operational, contains('.from("tasks")'));
    expect(operational, contains('.from("procurement_requests")'));
    expect(operational, contains('loadCandidateReadiness({'));
    expect(operational, contains('incoming_candidate_readiness'));
  });

  test('будущая дата не превращает пустой табель в прогул', () {
    expect(operational, contains('dateIsOnOrBefore(effectiveDate, baseDate)'));
    expect(operational, contains('Для будущей даты табель не трактуется как отсутствие'));
    expect(operational, contains('не автоматический вывод, что сотрудник прогулял смену'));
  });

  test('прораб остаётся в своём объекте а HR часть доступна только руководителю', () {
    expect(shared, contains('role === "foreman"'));
    expect(shared, contains('assignedObject'));
    expect(operational, contains('managerRole(role)'));
    expect(operational, contains('categoryEnabled(mode, "hr") && managerRole(role)'));
  });

  test('read-only goal context и metadata не содержат entity ids', () {
    expect(shared, contains('topic: conversationTopic'));
    expect(shared, contains('issue_count: issueCount'));
    expect(shared, contains('affected_count: affectedCount'));
    final metaStart = shared.indexOf('function goalMetadata');
    final metaEnd = shared.indexOf('export function readOnlyGoalBody', metaStart);
    expect(metaStart, greaterThanOrEqualTo(0));
    expect(metaEnd, greaterThan(metaStart));
    final metadata = shared.substring(metaStart, metaEnd);
    expect(metadata, isNot(contains('employee_id')));
    expect(metadata, isNot(contains('application_id')));
    expect(metadata, isNot(contains('request_id')));
  });

  test('операционный режим только диагностирует факты а не двигает статусы', () {
    expect(operational, isNot(contains('buildProcurementStatus')));
    expect(operational, isNot(contains('prepare_timesheet_correction')));
    expect(operational, contains('Goal planner ничего не закрывает и не двигает автоматически'));
  });

  test('цель сохраняется между репликами без доверенных entity ids', () {
    expect(conversation, contains('"goal_candidate_readiness"'));
    expect(conversation, contains('"goal_operational_risk"'));
    expect(conversation, contains('goalTopic(context.topic)'));
    expect(conversation, contains('topic === "action_trace" ? 8000 : 800'));
    expect(conversation, contains('goalTopic(topic) ? 1500 : legacyPromptBudget'));
    expect(wrapper, contains('conversationContext = emptyConversationContext'));
    expect(index, contains('conversationContext,'));
    expect(index, contains('baseDate: base.toISOString().slice(0, 10)'));
    expect(goal, contains('shortGoalFollowUp'));
    expect(goal, contains('contextGoalKind'));
  });

  test('короткие drill-down реплики остаются в том же goal router', () {
    expect(goal, contains('только|лишь|покажи\\s+только|оставь\\s+только'));
    expect(goal, contains('подготовь|напомни|напиши|сделай\\s+что\\s+мож'));
    expect(candidate, contains('conversationContext.topic === "goal_candidate_readiness"'));
    expect(operational, contains('conversationContext.topic === "goal_operational_risk"'));
  });
}
