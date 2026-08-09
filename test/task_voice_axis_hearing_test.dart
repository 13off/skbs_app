import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_active_field.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_axis_hearing.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_strict_session.dart';
import 'package:skbs_app/models/employee.dart';

void main() {
  final now = DateTime(2026, 8, 8, 12);

  test('варианты произношения букв приводятся к канонической форме', () {
    expect(
      normalizeTaskVoiceAxesValue('пять восемь бе ге'),
      'пять восемь бэ гэ',
    );
    expect(
      normalizeTaskVoiceAxesValue('5 8 вэ де'),
      '5 8 вэ дэ',
    );
  });

  test('слепленные браузером буквы разбираются как диапазон букв', () {
    expect(
      normalizeTaskVoiceAxesValue('пять восемь бэгэ'),
      'пять восемь бэ гэ',
    );
    expect(
      normalizeTaskVoiceAxesValue('пять восемь беге'),
      'пять восемь бэ гэ',
    );
    expect(
      normalizeTaskVoiceAxesValue('пять восемь беги'),
      'пять восемь бэ гэ',
    );
  });

  test('фонетические имена букв разбираются как оси', () {
    expect(
      normalizeTaskVoiceAxesValue('пять восемь Борис Григорий'),
      'пять восемь бэ гэ',
    );
    expect(
      normalizeTaskVoiceAxesValue('7 10 Виктор Дмитрий'),
      '7 10 вэ дэ',
    );
  });

  test('до двух шумовых слов внутри осей не обрывают разбор', () {
    expect(
      normalizeTaskVoiceAxesValue('пять восемь помеха шум бэ гэ'),
      'пять восемь бэ гэ',
    );
    expect(
      normalizeTaskVoiceAxesValue('пять восемь эээ бэ гэ'),
      'пять восемь бэ гэ',
    );
  });

  test('цифра 6 после двух осевых чисел может быть короткой буквой Б', () {
    expect(
      normalizeTaskVoiceAxesValue('5 8 6 гэ'),
      '5 8 бэ гэ',
    );
  });

  test('активное поле осей нормализует отдельную следующую фразу', () {
    final routed = routeTaskVoiceTranscript(
      transcript: 'пять восемь беги',
      activeField: TaskVoiceField.axes,
    );
    expect(routed, 'оси пять восемь бэ гэ');

    final result = applyForemanVoiceSession(
      transcript: routed,
      now: now,
      employees: const <Employee>[],
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '',
      initialWork: 'Армирование стены',
      initialAssigneeIds: const <String>['worker'],
      allowDateChange: false,
      goalTask: false,
    );
    expect(result.axes, '5–8 / Б–Г');
    expect(result.changedFields, contains('оси'));
  });

  test('явная команда осей тоже проходит слуховой нормализатор', () {
    expect(
      routeTaskVoiceTranscript(
        transcript: 'оси 7 10 веге',
        activeField: TaskVoiceField.work,
      ),
      'оси 7 10 вэ гэ',
    );
  });

  test('Web Speech оценивает осевой шаблон только в осевом контексте', () {
    final web = File(
      'lib/features/tasks/voice/task_voice_recognition_web.dart',
    ).readAsStringSync();

    expect(web, contains("setProperty('maxAlternatives'.toJS, 3.toJS)"));
    expect(web, contains('scoreTaskVoiceAxesCandidate(text)'));
    expect(web, contains('prioritizeAxes'));
    expect(web, contains('scoreTaskVoiceRecognitionHints(text, hints)'));
    expect(web, isNot(contains('_axisSpeechHints')));
  });
}
