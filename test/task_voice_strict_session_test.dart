import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_strict_session.dart';
import 'package:skbs_app/models/employee.dart';

void main() {
  const employees = <Employee>[
    Employee(
      'Иванов Иван Сергеевич',
      'Арматурщик',
      '',
      id: 'ivanov',
      objectName: 'Мурманск',
    ),
    Employee(
      'Петров Пётр Андреевич',
      'Бетонщик',
      '',
      id: 'petrov',
      objectName: 'Мурманск',
    ),
  ];
  final now = DateTime(2026, 8, 8, 10);

  test('речь без маркера поля ничего не меняет', () {
    final result = applyForemanVoiceSession(
      transcript: 'завтра Иванов армирование стены пять восемь б г',
      now: now,
      employees: employees,
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '1–2 / А–Б',
      initialWork: 'Опалубка стены',
      initialAssigneeIds: const <String>['petrov'],
      allowDateChange: true,
      goalTask: false,
    );

    expect(result.date, DateTime(2026, 8, 8));
    expect(result.axes, '1–2 / А–Б');
    expect(result.work, 'Опалубка стены');
    expect(result.assigneeIds, <String>['petrov']);
    expect(result.changedFields, isEmpty);
    expect(result.warning, contains('Сначала выберите поле'));
  });

  test('маркер оси меняет только оси', () {
    final result = applyForemanVoiceSession(
      transcript: 'завтра Иванов армирование стены, оси 5 8 б г',
      now: now,
      employees: employees,
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '1–2 / А–Б',
      initialWork: 'Опалубка стены',
      initialAssigneeIds: const <String>['petrov'],
      allowDateChange: true,
      goalTask: false,
    );

    expect(result.date, DateTime(2026, 8, 8));
    expect(result.axes, '5–8 / Б–Г');
    expect(result.work, 'Опалубка стены');
    expect(result.assigneeIds, <String>['petrov']);
    expect(result.changedFields, <String>{'оси'});
  });

  test('каждый маркер маршрутизирует речь только в своё поле', () {
    final result = applyForemanVoiceSession(
      transcript:
          'дата послезавтра, оси 5 8 б г, вид работ армирование стены, исполнитель Иванов',
      now: now,
      employees: employees,
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '',
      initialWork: '',
      initialAssigneeIds: const <String>[],
      allowDateChange: true,
      goalTask: false,
    );

    expect(result.date, DateTime(2026, 8, 10));
    expect(result.axes, '5–8 / Б–Г');
    expect(result.work.toLowerCase(), 'армирование стены');
    expect(result.assigneeIds, <String>['ivanov']);
    expect(result.missingFields, isEmpty);
  });

  test('фамилия в виде работ не выбирает исполнителя', () {
    final result = applyForemanVoiceSession(
      transcript: 'вид работ проверить армирование Иванова',
      now: now,
      employees: employees,
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '1–2 / А–Б',
      initialWork: '',
      initialAssigneeIds: const <String>['petrov'],
      allowDateChange: false,
      goalTask: false,
    );

    expect(result.work, contains('Иванова'));
    expect(result.assigneeIds, <String>['petrov']);
    expect(result.changedFields, <String>{'задача'});
  });

  test('исполнитель поддерживает замену добавление и удаление только после маркера', () {
    final result = applyForemanVoiceSession(
      transcript:
          'Иванов. исполнитель Иванов. исполнитель добавь ещё Петрова. исполнитель убери Иванова',
      now: now,
      employees: employees,
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '1–2 / А–Б',
      initialWork: 'Армирование стены',
      initialAssigneeIds: const <String>[],
      allowDateChange: false,
      goalTask: false,
    );

    expect(result.assigneeIds, <String>['petrov']);
  });

  test('пакетные задачи тоже требуют явных маркеров полей', () {
    final unlabeled = parseForemanTaskVoiceBatch(
      transcript:
          'Иванову оси 1 2 а б армирование. Следующая задача Петрову оси 3 4 в г опалубка.',
      now: now,
      employees: employees,
    );
    expect(unlabeled, isEmpty);

    final labeled = parseForemanTaskVoiceBatch(
      transcript:
          'оси 1 2 а б, вид работ армирование, исполнитель Иванов. '
          'Следующая задача: оси 3 4 в г, вид работ опалубка, исполнитель Петров.',
      now: now,
      employees: employees,
    );
    expect(labeled, hasLength(2));
    expect(labeled.first.assigneeIds, <String>['ivanov']);
    expect(labeled.last.assigneeIds, <String>['petrov']);
  });

  test('форма создания задачи подключает строгий голосовой движок', () {
    final source = File('lib/screens/add_task_screen.dart').readAsStringSync();
    expect(source, contains('task_voice_strict_session.dart'));
    expect(source, isNot(contains("import '../features/tasks/voice/task_voice_session.dart';")));
  });
}
