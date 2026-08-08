import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('форма прораба использует усиленный разбор осей через строгий роутер', () {
    final screen = File('lib/screens/add_task_screen.dart').readAsStringSync();
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();
    final strict = File(
      'lib/features/tasks/voice/task_voice_strict_session.dart',
    ).readAsStringSync();
    final robust = File(
      'lib/features/tasks/voice/task_voice_parser_robust.dart',
    ).readAsStringSync();

    expect(screen, contains('task_voice_strict_session.dart'));
    expect(strict, contains("import 'task_voice_parser_robust.dart';"));
    expect(strict, contains("transcript: 'оси \$value'"));
    expect(strict, contains('parseForemanTaskVoice('));
    expect(voice, contains("'бэ'"));
    expect(robust, contains("last.raw.trim() == '6'"));
    expect(robust, contains('вид\\s+работ'));
  });
}
