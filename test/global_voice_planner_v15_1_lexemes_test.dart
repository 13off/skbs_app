import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planner принимает естественную форму первым трём', () {
    final normalizer = File(
      'supabase/functions/ai-global-command/planner_prompt_normalizer.ts',
    ).readAsStringSync();
    expect(normalizer, contains('тр[её]м'));
    expect(normalizer, contains('троим'));
    expect(normalizer, isNot(contains(r'\b')));
  });

  test('passive HR filter не превращается в imperative назначение', () {
    final normalizer = File(
      'supabase/functions/ai-global-command/planner_prompt_normalizer.ts',
    ).readAsStringSync();
    expect(normalizer, contains('не\\s+назначен[а-яё]*'));
    expect(normalizer, contains('ответствен[а-яё]*\\s+не\\s+назначен'));
    expect(normalizer, contains('без ответственного'));
  });

  test('normalizer используется только для нового multi-step planner', () {
    final index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();
    expect(index, contains('normalizePlannerPrompt'));
    expect(index, contains('const plannerPrompt = normalizePlannerPrompt(rawPrompt)'));
    expect(index, contains('prompt: plannerPrompt'));
    expect(index, contains('prompt: rawPrompt'));
    expect(
      index.indexOf('buildActionTraceFollowUp({'),
      lessThan(index.indexOf('const plannerPrompt = normalizePlannerPrompt(rawPrompt)')),
    );
  });
}
