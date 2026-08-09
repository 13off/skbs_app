import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('семантический слой стоит только после точных боевых роутеров', () {
    final source = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();

    expect(source, contains('resolveSemanticVoiceIntent'));
    expect(source, contains('dispatchSemanticVoice'));
    expect(source, contains('semanticResultBody'));

    final exact = source.indexOf('if (procurementStatusIntent(prompt))');
    final semantic = source.indexOf('resolveSemanticVoiceIntent({');
    expect(exact, greaterThanOrEqualTo(0));
    expect(semantic, greaterThan(exact));
  });

  test('семантический роутер понимает смысловые синонимы и опечатки', () {
    final source = File(
      'supabase/functions/ai-global-command/semantic_router.ts',
    ).readAsStringSync();

    expect(source, contains('editDistance'));
    expect(source, contains('tokenLike'));
    expect(source, contains('"перекин"'));
    expect(source, contains('"закин"'));
    expect(source, contains('"закреп"'));
    expect(source, contains('"повесь"'));
    expect(source, contains('"прикреп"'));
    expect(source, contains('context.topic === "candidates"'));
    expect(source, contains('context.topic === "procurement"'));
  });

  test('LLM является только маршрутизатором и ограничен белым списком', () {
    final source = File(
      'supabase/functions/ai-global-command/semantic_router.ts',
    ).readAsStringSync();

    expect(source, contains('AI_INFERENCE_API_HOST'));
    expect(source, contains('Supabase'));
    expect(source, contains('allowedIntents'));
    expect(source, contains('writeIntents'));
    expect(source, contains('writeIntents.has(intent) ? 0.76 : 0.62'));
    expect(source, contains('не придумывай ФИО'));
    expect(source, contains('Верни только один intent из белого списка'));
    expect(source, isNot(contains('.from(')));
    expect(source, isNot(contains('.insert(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.delete(')));
  });

  test('семантические записи идут через существующие безопасные builders', () {
    final source = File(
      'supabase/functions/ai-global-command/semantic_dispatch.ts',
    ).readAsStringSync();

    expect(source, contains('buildHrStageMove'));
    expect(source, contains('buildCandidateResponsible'));
    expect(source, contains('buildCreateProcurementRequest'));
    expect(source, contains('buildProcurementStatus'));
    expect(source, contains('buildCreateLegalMatter'));
    expect(source, contains('buildLegalDecision'));
    expect(source, contains('buildBulkTimesheetResult'));
    expect(source, contains('ai-operational-draft'));
    expect(source, contains('ai-action-draft'));
    expect(source, contains('ai-document-draft'));
    expect(source, contains('ai-operational-insights'));
    expect(source, contains('ai-search'));
  });

  test('смысл не загрязняет ФИО материал количество и объект', () {
    final source = File(
      'supabase/functions/ai-global-command/semantic_dispatch.ts',
    ).readAsStringSync();

    expect(source, contains('prompt: originalPrompt'));
    expect(source, contains(r'prompt: `${originalPrompt} создай задачу`'));
    expect(source, contains(r'prompt: `${originalPrompt} исправь табель смены`'));
    expect(source, contains(r'prompt: `создай юридический вопрос: ${originalPrompt}`'));
    expect(
      source,
      contains('Semantic routing decides WHAT the user means.'),
    );
  });

  test('невыход безопасно канонизируется в ноль смен без общего угадывания', () {
    final source = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();

    expect(source, contains('const absenceWrite ='));
    expect(source, contains(r'`${prompt} табель смены`'));
    expect(source, contains(r'`${prompt} 0 смен`'));
    expect(source, contains('originalPrompt: absenceWrite'));
  });

  test('исходная фраза сохраняется рядом с семантической подсказкой', () {
    final source = File(
      'supabase/functions/ai-global-command/semantic_router.ts',
    ).readAsStringSync();

    expect(source, contains('semanticPrompt'));
    expect(
      source,
      contains(r'${originalPrompt}\n\nСистемная семантическая подсказка'),
    );
    expect(source, contains('source: "llm"'));
    expect(source, contains('return llm ?? local'));
  });
}
