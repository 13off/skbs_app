import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('форма прораба использует усиленный разбор осей', () {
    final screen = File('lib/screens/add_task_screen.dart').readAsStringSync();
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();
    final session = File(
      'lib/features/tasks/voice/task_voice_session.dart',
    ).readAsStringSync();
    final robust = File(
      'lib/features/tasks/voice/task_voice_parser_robust.dart',
    ).readAsStringSync();

    expect(screen, contains('task_voice_session.dart'));
    expect(session, contains("import 'task_voice_parser_robust.dart';"));
    expect(session, contains('parseForemanTaskVoice('));
    expect(voice, contains("'бэ'"));
    expect(robust, contains("last.raw.trim() == '6'"));
    expect(robust, contains('вид\\s+работ'));
  });
}
