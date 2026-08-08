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
    final shell = File('lib/screens/add_task_screen.dart').readAsStringSync();

    expect(view, contains('if (widget.allowDraft)'));
    expect(view, contains('buildVoiceAssistantCard()'));
    expect(voice, contains('Дата • оси • вид работ • исполнитель'));
    expect(voice, contains('applyForemanVoiceSession('));
    expect(voice, contains('selectedAssigneeIds'));
    expect(voice, contains('axesController.text'));
    expect(voice, contains('workController.text'));
    expect(voice, contains('selectedDate = result.date'));
    expect(shell, contains('task_voice_strict_session.dart'));
  });

  test('PWA слушает до Стоп или голосового готово и использует подсказки', () {
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();
    final session = File(
      'lib/features/tasks/voice/task_voice_session.dart',
    ).readAsStringSync();
    final web = File(
      'lib/features/tasks/voice/task_voice_recognition_web.dart',
    ).readAsStringSync();

    expect(voice, contains("? 'Стоп'"));
    expect(voice, contains('stopTaskVoiceRecognition()'));
    expect(voice, contains('buildTaskVoiceHints('));
    expect(voice, contains("'дату'"));
    expect(voice, contains("'добавь ещё'"));
    expect(voice, contains("'начнём заново'"));
    expect(session, contains('_hasStopCommand'));
    expect(session, contains('вс[её]\\s+готово'));
    expect(web, contains("setProperty('continuous'.toJS, true.toJS)"));
    expect(web, contains("setProperty('interimResults'.toJS, true.toJS)"));
    expect(web, contains("setProperty('maxAlternatives'.toJS, 3.toJS)"));
    expect(web, contains('_applySpeechGrammar'));
    expect(web, contains('session.stopRequested'));
    expect(web, contains("callMethod<JSAny?>('stop'.toJS)"));
    expect(web, isNot(contains('Duration(seconds: 18)')));
  });

  test('PWA обновляет только явно выбранное поле прямо во время речи', () {
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();
    final strict = File(
      'lib/features/tasks/voice/task_voice_strict_session.dart',
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
    expect(voice, contains('Пока поле не названо, речь никуда не записывается'));
    expect(voice, contains('Каждая команда меняет только выбранное поле'));
    expect(voice, contains('Все четыре поля распознаны'));
    expect(voice, contains('Ещё нужно:'));
    expect(strict, contains('_findStrictMarkers'));
    expect(strict, contains('Сначала выберите поле голосом'));
    expect(web, contains('_publishPartial(session)'));
    expect(web, contains('session.onPartial?.call(text)'));
    expect(web, contains('session.interim'));
  });

  test('фамилии вынесены в отдельный фонетический matcher', () {
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();
    final matcher = File(
      'lib/features/tasks/voice/task_voice_employee_matcher.dart',
    ).readAsStringSync();
    final robust = File(
      'lib/features/tasks/voice/task_voice_parser_robust.dart',
    ).readAsStringSync();

    expect(voice, contains('buildTaskVoiceHints('));
    expect(matcher, contains('final surnames = <String>[]'));
    expect(matcher, contains('...surnames'));
    expect(matcher, contains('...fullNames'));
    expect(matcher, contains('taskVoicePhoneticKey'));
    expect(matcher, contains('taskVoiceEditDistance'));
    expect(matcher, contains('resolveTaskVoiceEmployeeIds'));
    expect(voice, contains('исполнитель Фамилия'));
    expect(voice, contains('Фамилию пока не понял'));
    expect(robust, contains('_matchFuzzyEmployees'));
  });

  test('Voice Assistant v2 умеет команды и пакетные задачи с ручным сохранением', () {
    final session = File(
      'lib/features/tasks/voice/task_voice_session.dart',
    ).readAsStringSync();
    final strict = File(
      'lib/features/tasks/voice/task_voice_strict_session.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/screens/task_create/task_create_actions.dart',
    ).readAsStringSync();
    final view = File(
      'lib/screens/task_create/task_create_view.dart',
    ).readAsStringSync();

    expect(session, contains('normalizeTaskVoiceWork'));
    expect(strict, contains('добавь'));
    expect(strict, contains('убери'));
    expect(strict, contains('parseForemanTaskVoiceBatch'));
    expect(actions, contains('buildVoiceAdditionalResults'));
    expect(actions, contains('TaskRepository.addTaskWithDetails'));
    expect(view, contains(r'Сохранить $batchCount задачи'));
  });

  test('на Главной нет отдельной кнопки голосовой записи', () {
    final sections = File(
      'lib/screens/home/home_sections.dart',
    ).readAsStringSync();

    expect(sections, isNot(contains('Поставить задачу голосом')));
    expect(sections, isNot(contains('buildVoiceTaskQuickAction()')));
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
