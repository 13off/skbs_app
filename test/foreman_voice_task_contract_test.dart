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
    expect(voice, contains('parseForemanTaskVoice('));
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
    expect(voice, contains('_buildTaskVoiceHints(employees)'));
    expect(voice, contains('employee.name.trim()'));
    expect(web, contains("setProperty('continuous'.toJS, true.toJS)"));
    expect(web, contains("setProperty('interimResults'.toJS, true.toJS)"));
    expect(web, contains("setProperty('maxAlternatives'.toJS, 3.toJS)"));
    expect(web, contains('_applySpeechGrammar'));
    expect(web, contains('session.stopRequested'));
    expect(web, contains("callMethod<JSAny?>('stop'.toJS)"));
    expect(web, isNot(contains('Duration(seconds: 18)')));
  });

  test('PWA обновляет поля задачи прямо во время речи', () {
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();
    final recognition = File(
      'lib/features/tasks/voice/task_voice_recognition.dart',
    ).readAsStringSync();
    final web = File(
      'lib/features/tasks/voice/task_voice_recognition_web.dart',
    ).readAsStringSync();

    expect(recognition, contains('void Function(String transcript)? onPartial'));
    expect(voice, contains('onPartial: applyVoicePartial'));
    expect(voice, contains('void applyVoicePartial(String transcript)'));
    expect(voice, contains('Поля заполняются сразу'));
    expect(voice, contains('Все четыре поля распознаны'));
    expect(voice, contains('Ещё нужно:'));
    expect(web, contains('_publishPartial(session)'));
    expect(web, contains('session.onPartial?.call(text)'));
    expect(web, contains('session.interim'));
  });

  test('фамилии получают приоритет, фонетическое сравнение и живую коррекцию', () {
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();
    final robust = File(
      'lib/features/tasks/voice/task_voice_parser_robust.dart',
    ).readAsStringSync();

    expect(voice, contains('final surnames = <String>[]'));
    expect(voice, contains('...surnames'));
    expect(voice, contains('...fullNames'));
    expect(voice, contains('_voicePhoneticKey'));
    expect(voice, contains('_voiceEditDistance'));
    expect(voice, contains('_resolveVoiceEmployeeIds'));
    expect(voice, contains('markers.last.end'));
    expect(voice, contains('исполнитель Фамилия'));
    expect(voice, contains('Фамилию пока не понял'));
    expect(robust, contains('_matchFuzzyEmployees'));
  });

  test('приоритет фамилий идёт раньше общего строительного словаря', () {
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();

    final surnames = voice.indexOf('...surnames');
    final domain = voice.indexOf('..._taskVoiceDomainHints');
    expect(surnames, greaterThanOrEqualTo(0));
    expect(domain, greaterThan(surnames));
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
