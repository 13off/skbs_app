import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('документация фиксирует большие разговорные сценарии v15', () {
    final examples = File(
      'supabase/functions/ai-global-command/README_v15_examples.md',
    ).readAsStringSync();

    expect(examples, contains('сегодня не вышел'));
    expect(examples, contains('первым двум поставь 0'));
    expect(examples, contains('кандидатов без ответственного'));
    expect(examples, contains('неполным комплектом документов'));
    expect(examples, contains('вылетает завтра'));
    expect(examples, contains('не ответил на последнее сообщение'));
    expect(examples, contains('просроченные срочные заявки'));
    expect(examples, contains('открой второго'));
  });
}
