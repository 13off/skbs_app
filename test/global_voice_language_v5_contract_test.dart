import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('глобальный голос принимает разговорные формулировки', () {
    final shared = File(
      'supabase/functions/ai-global-command/shared.ts',
    ).readAsStringSync();
    final navigation = File(
      'supabase/functions/ai-global-command/navigation.ts',
    ).readAsStringSync();

    expect(shared, contains('покажи|показать|выведи|вывести'));
    expect(shared, contains('приземлился|приземлилась'));
    expect(shared, contains('перекинь|перекинуть|передвинь|передвинуть'));
    expect(shared, contains('подтверди|подтвердить'));
    expect(shared, contains('верни|вернуть'));
    expect(navigation, contains('персонал|бригада|работник'));
    expect(navigation, contains('найм|соискател|ваканс'));
    expect(navigation, contains('контрагент'));
    expect(navigation, contains('материал'));
  });

  test('оперативные вопросы обрабатываются локально и без write action', () {
    final index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();
    final queries = File(
      'supabase/functions/ai-global-command/operational_queries.ts',
    ).readAsStringSync();

    expect(index, contains('operationalQueryIntent(prompt)'));
    expect(index, contains('buildOperationalQuery({'));
    expect(queries, contains('Сводка по сотрудникам'));
    expect(queries, contains('Сводка по задачам'));
    expect(queries, contains('Сводка по кандидатам'));
    expect(queries, contains('Сводка по снабжению'));
    expect(queries, contains('action: null'));
    expect(queries, contains('preliminary: false'));
  });
}
