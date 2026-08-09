import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/data/global_voice_context_controller.dart';

void main() {
  tearDown(() {
    GlobalVoiceContextController.clear();
  });

  test('ссылочный follow-up выполняется до обычных intent parser-ов', () {
    final source = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();

    final reference = source.indexOf('buildReferencedFollowUp({');
    final firstLegacyIntent = source.indexOf('if (uiSettingIntent(prompt))');
    expect(reference, greaterThanOrEqualTo(0));
    expect(firstLegacyIntent, greaterThan(reference));
    expect(source, contains('prompt: rawPrompt'));
  });

  test('reference router заново читает сущности из БД, а не доверяет клиентским id', () {
    final source = File(
      'supabase/functions/ai-global-command/reference_followup.ts',
    ).readAsStringSync();

    expect(source, contains('.from("employees")'));
    expect(source, contains('.from("recruitment_applications")'));
    expect(source, contains('.from("procurement_requests")'));
    expect(source, contains('.from("attendance")'));
    expect(source, isNot(contains('reference_context')));
    expect(source, contains('companyId'));
    expect(source, contains('role === "foreman"'));
  });

  test('русские ссылки разбираются лексемами без ASCII word boundary', () {
    final source = File(
      'supabase/functions/ai-global-command/reference_followup.ts',
    ).readAsStringSync();

    expect(source, contains('export function referenceWords'));
    expect(source, contains(r'.replace(/[^а-яa-z0-9.,]+/g, " ")'));
    expect(source, contains(r'.map((word) => word.replace(/^[.,]+|[.,]+$/g, ""))'));
    expect(source, contains('word.startsWith(root)'));
    expect(source, contains('pluralPronouns.has(word)'));
    expect(source, isNot(contains(r'/\b(?:им|их')));
    expect(source, isNot(contains(r'перв\w*')));
  });

  test('местоимения и порядковые ссылки поддерживаются явно', () {
    final source = File(
      'supabase/functions/ai-global-command/reference_followup.ts',
    ).readAsStringSync();

    for (final token in <String>[
      'им',
      'их',
      'этому',
      'ему',
      'перв',
      'втор',
      'трет',
      'последн',
    ]) {
      expect(source, contains(token));
    }
    expect(source, contains('entities.length > 30'));
  });

  test('значения смен используют русские лексемы и десятичные формы', () {
    final source = File(
      'supabase/functions/ai-global-command/reference_followup.ts',
    ).readAsStringSync();

    expect(source, contains('export function shiftValue'));
    expect(source, contains('"нули"'));
    expect(source, contains('"0,5"'));
    expect(source, contains('"1,5"'));
    expect(source, contains('"2,5"'));
    expect(source, contains('prefix(["нулев"])'));
    expect(source, isNot(contains(r'/\b(?:ноль|нули')));
  });

  test('невыход становится ссылочным списком разговора', () {
    final conversation = File(
      'supabase/functions/ai-global-command/conversation_context.ts',
    ).readAsStringSync();
    final semantic = File(
      'supabase/functions/ai-global-command/semantic_dispatch.ts',
    ).readAsStringSync();

    expect(conversation, contains('"absence_today"'));
    expect(semantic, contains('return "absence_today"'));
    expect(semantic, contains('attachInsightConversation'));
    expect(semantic, contains('query_mode: "list"'));
  });

  test('ссылочная запись наследует дату исходного результата', () {
    final source = File(
      'supabase/functions/ai-global-command/reference_followup.ts',
    ).readAsStringSync();

    expect(source, contains('hasExplicitDate(prompt)'));
    expect(source, contains('conversationContext.date || date'));
    expect(source, contains('timesheetAction(entity, shifts, effectiveDate)'));
  });

  test('массовая ссылочная запись остаётся пакетом подтверждаемых действий', () {
    final source = File(
      'supabase/functions/ai-global-command/reference_followup.ts',
    ).readAsStringSync();

    expect(source, contains('type: "prepare_timesheet_correction"'));
    expect(source, contains('type: "voice_compound_batch"'));
    expect(source, contains('confirmation_required: true'));
    expect(source, contains('buildCandidateResponsible'));
    expect(source, contains('buildHrStageMove'));
    expect(source, contains('buildProcurementStatus'));
  });

  test('разговорный список протухает через 30 минут', () {
    final old = DateTime.now()
        .subtract(const Duration(minutes: 31))
        .millisecondsSinceEpoch;
    GlobalVoiceContextController.state.value = GlobalVoiceContextSnapshot(
      companyId: 'company-1',
      conversationTopic: 'employees',
      conversationMode: 'list',
      conversationPrompt: 'кто сотрудники',
      conversationUpdatedAtMs: old,
    );

    final snapshot = GlobalVoiceContextController.snapshotFor('company-1');
    expect(snapshot, isNotNull);
    expect(snapshot!.conversationTopic, isEmpty);
    expect(snapshot.conversationPrompt, isEmpty);
    expect(snapshot.conversationUpdatedAtMs, 0);
  });

  test('уточнение и подготовленное действие протухают через 15 минут', () {
    final old = DateTime.now()
        .subtract(const Duration(minutes: 16))
        .millisecondsSinceEpoch;
    GlobalVoiceContextController.state.value = GlobalVoiceContextSnapshot(
      companyId: 'company-1',
      pendingClarificationPrompt: 'поставь им нули',
      pendingClarificationQuestion: 'Кому именно?',
      clarificationUpdatedAtMs: old,
      lastCommandPrompt: 'создай заявку',
      lastAction: const <String, dynamic>{'type': 'create_procurement_request'},
      lastTurnUpdatedAtMs: old,
    );

    final snapshot = GlobalVoiceContextController.snapshotFor('company-1');
    expect(snapshot, isNotNull);
    expect(snapshot!.pendingClarificationPrompt, isEmpty);
    expect(snapshot.lastCommandPrompt, isEmpty);
    expect(snapshot.lastAction, isEmpty);
  });
}
