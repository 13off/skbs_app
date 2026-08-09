import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA меняет словарь прямо во время одной голосовой сессии', () {
    final recognition = File(
      'lib/features/tasks/voice/task_voice_recognition.dart',
    ).readAsStringSync();
    final web = File(
      'lib/features/tasks/voice/task_voice_recognition_web.dart',
    ).readAsStringSync();
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();

    expect(recognition, contains('updateTaskVoiceRecognitionContext'));
    expect(web, contains('session.hints = cleanHints'));
    expect(web, contains('session.prioritizeAxes = prioritizeAxes'));
    expect(web, contains('_applySpeechGrammar(session.recognition, cleanHints)'));
    expect(voice, contains('if (nextActiveField != voiceActiveField)'));
    expect(voice, contains('_updateVoiceRecognitionField(nextActiveField)'));
    expect(voice, contains('activeField: field'));
    expect(voice, contains('prioritizeAxes: field == TaskVoiceField.axes'));
  });
}
