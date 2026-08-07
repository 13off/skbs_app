import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('голосовой ввод показывается только в сценарии прораба', () {
    final view = File(
      'lib/screens/task_create/task_create_view.dart',
    ).readAsStringSync();
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();

    expect(view, contains('if (widget.allowDraft)'));
    expect(view, contains('buildVoiceAssistantCard()'));
    expect(voice, contains('Дата • оси • задача • исполнители'));
    expect(voice, contains('parseTaskVoice('));
    expect(voice, contains('selectedAssigneeIds'));
    expect(voice, contains('axesController.text'));
    expect(voice, contains('workController.text'));
    expect(voice, contains('selectedDate = nextDate'));
  });

  test('PWA слушает до ручного Стоп и использует подсказки', () {
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();
    final web = File(
      'lib/features/tasks/voice/task_voice_recognition_web.dart',
    ).readAsStringSync();

    expect(voice, contains("? 'Стоп'"));
    expect(voice, contains('stopTaskVoiceRecognition()'));
    expect(voice, contains('_taskVoiceDomainHints'));
    expect(voice, contains('employee.name.trim()'));
    expect(web, contains("setProperty('continuous'.toJS, true.toJS)"));
    expect(web, contains("setProperty('interimResults'.toJS, true.toJS)"));
    expect(web, contains("setProperty('maxAlternatives'.toJS, 3.toJS)"));
    expect(web, contains('_applySpeechGrammar'));
    expect(web, contains('session.stopRequested'));
    expect(web, contains("callMethod<JSAny?>('stop'.toJS)"));
    expect(web, isNot(contains('Duration(seconds: 18)')));
  });

  test('Android и iOS запрашивают только нужные голосовые разрешения', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final androidActivity = File(
      'android/app/src/main/kotlin/ru/appstroy/skbs/MainActivity.kt',
    ).readAsStringSync();
    final iosPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final iosDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(androidManifest, contains('android.permission.RECORD_AUDIO'));
    expect(androidActivity, contains('ru.appstroy.skbs/task_voice'));
    expect(androidActivity, contains('SpeechRecognizer'));
    expect(iosPlist, contains('NSMicrophoneUsageDescription'));
    expect(iosPlist, contains('NSSpeechRecognitionUsageDescription'));
    expect(iosDelegate, contains('SFSpeechRecognizer'));
    expect(iosDelegate, contains('ru.appstroy.skbs/task_voice'));
  });
}
