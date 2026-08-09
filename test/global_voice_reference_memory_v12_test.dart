import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('местоимения и порядковые ссылки поддерживаются явно', () {
    final source = File(
      'supabase/functions/ai-global-command/reference_followup.ts',
    ).readAsStringSync();

    for (final token in <String>[
      'им',
      'их',
      'этому',
      'ему',
      'втор',
      'трет',
      'последн',
    ]) {
      expect(source, contains(token));
    }
    expect(source, contains('entities.length > 30'));
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
}
