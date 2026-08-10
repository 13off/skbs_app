import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v13 group router выполняется до стабильного v12 reference router', () {
    final source = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();

    final grouped = source.indexOf('buildGroupReferencedFollowUp({');
    final single = source.indexOf('buildReferencedFollowUp({');
    final legacy = source.indexOf('if (uiSettingIntent(prompt))');

    expect(grouped, greaterThanOrEqualTo(0));
    expect(single, greaterThan(grouped));
    expect(legacy, greaterThan(single));
  });

  test('группы, диапазоны и исключения разбираются без угадывания', () {
    final source = File(
      'supabase/functions/ai-global-command/group_reference_followup.ts',
    ).readAsStringSync();

    for (final marker in <String>[
      '["двум", 2]',
      '["троим", 3]',
      '["четверым", 4]',
      '["пятерым", 5]',
      'words.includes("по")',
      'ordinalAfter(words, "кроме")',
      'entities.slice(0, count)',
      'entities.slice(entities.length - count)',
      'Фраза про \${count} человек неоднозначна',
    ]) {
      expect(source, contains(marker));
    }
  });

  test('как вчера читает реальный табель и не придумывает отсутствующие значения', () {
    final source = File(
      'supabase/functions/ai-global-command/group_reference_followup.ts',
    ).readAsStringSync();

    expect(source, contains('sameAsYesterdayIntent'));
    expect(source, contains('.from("attendance")'));
    expect(source, contains('.eq("work_date", sourceDate)'));
    expect(source, contains('.in("employee_id", selected.map((entity) => entity.id))'));
    expect(source, contains('source_date: sourceDate'));
    expect(source, contains('нет однозначной записи'));
    expect(source, contains('status: 409'));
  });

  test('групповые записи сохраняют роли, объект прораба и подтверждение', () {
    final source = File(
      'supabase/functions/ai-global-command/group_reference_followup.ts',
    ).readAsStringSync();

    expect(source, contains('role === "foreman"'));
    expect(source, contains('entity.objectName === assignedObject'));
    expect(source, contains('type: "voice_compound_batch"'));
    expect(source, contains('confirmation_required: true'));
    expect(source, contains('buildCandidateResponsible'));
    expect(source, contains('buildHrStageMove'));
    expect(source, contains('buildProcurementStatus'));
  });

  test('v12 single reference router остаётся отдельным fallback слоем', () {
    final source = File(
      'supabase/functions/ai-global-command/reference_followup.ts',
    ).readAsStringSync();

    expect(source, contains('export function referenceWords'));
    expect(source, contains('export function shiftValue'));
    expect(source, contains('export async function buildReferencedFollowUp'));
    expect(source, contains('pluralPronouns'));
    expect(source, contains('singularPronouns'));
  });
}
