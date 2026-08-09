import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_active_field.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_strict_session.dart';
import 'package:skbs_app/models/employee.dart';

void main() {
  test('маркер выбирает активное поле без значения', () {
    expect(
      resolveTaskVoiceActiveField(
        transcript: 'оси',
        currentField: null,
      ),
      TaskVoiceField.axes,
    );
    expect(
      resolveTaskVoiceActiveField(
        transcript: 'вид работ',
        currentField: TaskVoiceField.axes,
      ),
      TaskVoiceField.work,
    );
  });

  test('разговорные названия тоже выбирают поле и становятся каноническими', () {
    expect(
      resolveTaskVoiceActiveField(transcript: 'ось', currentField: null),
      TaskVoiceField.axes,
    );
    expect(
      resolveTaskVoiceActiveField(transcript: 'задача', currentField: null),
      TaskVoiceField.work,
    );
    expect(
      resolveTaskVoiceActiveField(transcript: 'кто делает', currentField: null),
      TaskVoiceField.assignees,
    );
    expect(
      resolveTaskVoiceActiveField(transcript: 'когда', currentField: null),
      TaskVoiceField.date,
    );

    expect(
      routeTaskVoiceTranscript(
        transcript: 'работа армирование стены',
        activeField: null,
      ),
      'вид работ армирование стены',
    );
    expect(
      routeTaskVoiceTranscript(
        transcript: 'кто делает Иванов',
        activeField: null,
      ),
      'исполнитель Иванов',
    );
  });

  test('следующая фраза маршрутизируется только в активное поле', () {
    expect(
      routeTaskVoiceTranscript(
        transcript: 'пять восемь бэ гэ',
        activeField: TaskVoiceField.axes,
      ),
      'оси пять восемь бэ гэ',
    );
    expect(
      routeTaskVoiceTranscript(
        transcript: 'армирование стены',
        activeField: TaskVoiceField.work,
      ),
      'вид работ армирование стены',
    );
    expect(
      routeTaskVoiceTranscript(
        transcript: 'Иванов',
        activeField: TaskVoiceField.assignees,
      ),
      'исполнитель Иванов',
    );
  });

  test('отдельная фраза реально меняет только активные оси', () {
    final routed = routeTaskVoiceTranscript(
      transcript: 'пять восемь бэ гэ',
      activeField: TaskVoiceField.axes,
    );
    final result = applyForemanVoiceSession(
      transcript: routed,
      now: DateTime(2026, 8, 8),
      employees: const <Employee>[],
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '1–2 / А–Б',
      initialWork: 'Опалубка стены',
      initialAssigneeIds: const <String>['petrov'],
      allowDateChange: true,
      goalTask: false,
    );

    expect(result.axes, '5–8 / Б–Г');
    expect(result.work, 'Опалубка стены');
    expect(result.assigneeIds, <String>['petrov']);
    expect(result.changedFields, <String>{'оси'});
  });

  test('оси понимают шум, разговорные буквы и слепленные пары', () {
    final noisy = routeTaskVoiceTranscript(
      transcript: 'пять восемь эээ бешка гешка',
      activeField: TaskVoiceField.axes,
    );
    final glued = routeTaskVoiceTranscript(
      transcript: 'пять восемь бэгэ',
      activeField: TaskVoiceField.axes,
    );
    final latin = routeTaskVoiceTranscript(
      transcript: 'пять восемь b g',
      activeField: TaskVoiceField.axes,
    );

    expect(noisy, 'оси пять восемь бэ гэ');
    expect(glued, 'оси пять восемь бэ гэ');
    expect(latin, 'оси пять восемь бэ гэ');
  });

  test('явный новый маркер переключает поле и не получает старый префикс', () {
    expect(
      routeTaskVoiceTranscript(
        transcript: 'исполнитель Петров',
        activeField: TaskVoiceField.work,
      ),
      'исполнитель Петров',
    );
    expect(
      resolveTaskVoiceActiveField(
        transcript: 'исполнитель Петров',
        currentField: TaskVoiceField.work,
      ),
      TaskVoiceField.assignees,
    );
  });

  test('управляющие команды не превращаются в значение активного поля', () {
    expect(
      routeTaskVoiceTranscript(
        transcript: 'готово',
        activeField: TaskVoiceField.axes,
      ),
      'готово',
    );
    expect(
      resolveTaskVoiceActiveField(
        transcript: 'начнём заново',
        currentField: TaskVoiceField.axes,
      ),
      isNull,
    );
  });

  test('форма показывает и подсвечивает активное поле', () {
    final shell = File('lib/screens/add_task_screen.dart').readAsStringSync();
    final voice = File(
      'lib/screens/task_create/task_create_voice.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/task_create/task_create_sections.dart',
    ).readAsStringSync();
    final view = File(
      'lib/screens/task_create/task_create_view.dart',
    ).readAsStringSync();

    expect(shell, contains('TaskVoiceField? voiceActiveField'));
    expect(voice, contains('Активное поле:'));
    expect(voice, contains('routeTaskVoiceTranscript('));
    expect(voice, contains('resolveTaskVoiceActiveField('));
    expect(sections, contains('isVoiceFieldActive(TaskVoiceField.axes)'));
    expect(sections, contains('isVoiceFieldActive(TaskVoiceField.work)'));
    expect(sections, contains('isVoiceFieldActive(TaskVoiceField.assignees)'));
    expect(view, contains('isVoiceFieldActive(TaskVoiceField.date)'));
  });
}
