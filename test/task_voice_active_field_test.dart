import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_active_field.dart';

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
