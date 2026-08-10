import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_fuzzy_reranker.dart';

void main() {
  test('каждый поддержанный action оставляет короткий серверный trace', () {
    final shared = File(
      'supabase/functions/ai-global-command/shared.ts',
    ).readAsStringSync();
    final trace = File(
      'supabase/functions/ai-global-command/action_trace.ts',
    ).readAsStringSync();

    expect(shared, contains('buildActionConversation'));
    expect(shared, contains('{ conversation }'));
    expect(trace, contains('topic: "action_trace"'));
    expect(trace, contains('query_mode: "action"'));
    expect(trace, contains('Date.now()'));
    expect(trace, contains('rawActions.slice(0, 30)'));
    expect(trace, contains('payload.length > 7800'));
  });

  test('action trace проходит отдельным router до v13 и v12', () {
    final source = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();
    final v14 = source.indexOf('buildActionTraceFollowUp({');
    final v13 = source.indexOf('buildGroupReferencedFollowUp({');
    final v12 = source.indexOf('buildReferencedFollowUp({');

    expect(v14, greaterThanOrEqualTo(0));
    expect(v13, greaterThan(v14));
    expect(v12, greaterThan(v13));
    expect(source, contains('prompt: rawPrompt'));
  });

  test('trace имеет TTL и не используется как авторизация', () {
    final context = File(
      'supabase/functions/ai-global-command/conversation_context.ts',
    ).readAsStringSync();
    final followUp = File(
      'supabase/functions/ai-global-command/action_trace_followup.ts',
    ).readAsStringSync();

    expect(context, contains('"action_trace"'));
    expect(context, contains('"action"'));
    expect(context, contains('topic === "action_trace" ? 8000 : 800'));
    expect(followUp, contains('const traceTtlMs = 15 * 60 * 1000'));
    expect(followUp, contains('futureSkewMs'));
    expect(followUp, contains('.from("recruitment_applications")'));
    expect(followUp, contains('.from("employees")'));
    expect(followUp, contains('.from("procurement_requests")'));
    expect(followUp, contains('.eq("company_id", companyId)'));
    expect(followUp, contains('role === "foreman"'));
    expect(followUp, contains('.eq("object_name", assignedObject)'));
    expect(followUp, isNot(contains('.insert(')));
    expect(followUp, isNot(contains('.update(')));
    expect(followUp, isNot(contains('.delete(')));
  });

  test('цепочка кандидата умеет открыть карточку и подготовить сообщение', () {
    final followUp = File(
      'supabase/functions/ai-global-command/action_trace_followup.ts',
    ).readAsStringSync();
    final router = File(
      'lib/features/ai/actions/global_voice_action_router.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/features/ai/actions/global_voice_extended_action_coordinator.dart',
    ).readAsStringSync();

    expect(followUp, contains('type: "open_candidate_detail"'));
    expect(followUp, contains('type: "send_candidate_message"'));
    expect(followUp, contains('target.source === "telegram"'));
    expect(followUp, contains('target.source === "max"'));
    expect(followUp, contains('confirmation_required: true'));
    expect(router, contains("action.type == 'open_candidate_detail'"));
    expect(router, contains('RecruitmentRepository.fetchWorkspace'));
    expect(router, contains('application.id == applicationId'));
    expect(coordinator, contains("'send_candidate_message'"));
    expect(coordinator, contains('AiActionAuditRepository.createProposed'));
    expect(coordinator, contains('RecruitmentRepository.sendCandidateMessage'));
  });

  test('след действия поддерживает группы и безопасное продолжение табеля', () {
    final source = File(
      'supabase/functions/ai-global-command/action_trace_followup.ts',
    ).readAsStringSync();

    expect(source, contains('ordinalIndexes'));
    expect(source, contains('groupCount'));
    expect(source, contains('words.includes("по")'));
    expect(source, contains('ordinalAfter(words, "кроме")'));
    expect(source, contains('shiftValue(prompt)'));
    expect(source, contains('Чтобы не продублировать тот же табель'));
    expect(source, contains('shiftById'));
    expect(source, contains('timesheetAction(target'));
    expect(source, contains('type: "voice_compound_batch"'));
  });

  test('fuzzy reranker помогает только длинным словам', () {
    expect(scoreTaskVoiceFuzzyHints('иваноф', const <String>['иванов']), greaterThan(0));
    expect(scoreTaskVoiceFuzzyHints('бетонированее', const <String>['бетонирование']), greaterThan(0));
    expect(scoreTaskVoiceFuzzyHints('им', const <String>['их']), 0);
    expect(scoreTaskVoiceFuzzyHints('бе', const <String>['ве']), 0);
    expect(scoreTaskVoiceFuzzyHints('иванов', const <String>['иванов']), 0);
  });

  test('Web Speech оценивает пять сырых альтернатив без подмены текста', () {
    final source = File(
      'lib/features/tasks/voice/task_voice_recognition_web.dart',
    ).readAsStringSync();

    expect(source, contains("'maxAlternatives'.toJS, 5.toJS"));
    expect(source, contains('length > 5 ? 5 : length'));
    expect(source, contains('scoreTaskVoiceFuzzyHints(text, hints)'));
    expect(
      source,
      contains('final text = (transcriptValue as JSString).toDart.trim();'),
    );
    expect(source, contains('никогда не переписывает текст для аудита'));
  });
}
