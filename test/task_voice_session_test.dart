import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_employee_matcher.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_session.dart';
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
    Employee(
      'Дементьев Борис Викторович',
      'Бетонщик',
      '',
      id: 'dementev',
      objectName: 'Мурманск',
    ),
  ];
  final now = DateTime(2026, 8, 8, 10);

  test('в одной записи можно исправлять поля и состав исполнителей', () {
    final result = applyForemanVoiceSession(
      transcript:
          'На завтра оси 1 2 а б закончить армирование стены исполнитель Иванов. '
          'Нет, дату послезавтра. Поменяй только оси 5 8 б г. '
          'Добавь ещё Петрова. Убери Иванова. Вид работ бетонирование. Всё готово.',
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
    expect(result.work.toLowerCase(), 'бетонирование');
    expect(result.assigneeIds, <String>['petrov']);
    expect(result.shouldStop, isTrue);
    expect(result.missingFields, isEmpty);
  });

  test('оставь дату не трогает дату и меняет только оси', () {
    final result = applyForemanVoiceSession(
      transcript: 'Оставь дату. Поменяй только оси 7 10 б д.',
      now: now,
      employees: employees,
      initialDate: DateTime(2026, 8, 9),
      initialAxes: '1–2 / А–Б',
      initialWork: 'Армирование стены',
      initialAssigneeIds: const <String>['ivanov'],
      allowDateChange: true,
      goalTask: false,
    );

    expect(result.date, DateTime(2026, 8, 9));
    expect(result.axes, '7–10 / Б–Д');
    expect(result.work, 'Армирование стены');
    expect(result.assigneeIds, <String>['ivanov']);
  });

  test('убери исполнителя удаляет только названного сотрудника', () {
    final result = applyForemanVoiceSession(
      transcript: 'Убери Иванова',
      now: now,
      employees: employees,
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '1–2 / А–Б',
      initialWork: 'Армирование стены',
      initialAssigneeIds: const <String>['ivanov', 'petrov'],
      allowDateChange: false,
      goalTask: false,
    );

    expect(result.assigneeIds, <String>['petrov']);
  });

  test('очисти исполнителей снимает всех', () {
    final result = applyForemanVoiceSession(
      transcript: 'Очисти исполнителей',
      now: now,
      employees: employees,
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '1–2 / А–Б',
      initialWork: 'Армирование стены',
      initialAssigneeIds: const <String>['ivanov', 'petrov'],
      allowDateChange: false,
      goalTask: false,
    );

    expect(result.assigneeIds, isEmpty);
    expect(result.missingFields, contains('исполнители'));
  });

  test('последний явный маркер исполнителя заменяет предыдущий', () {
    final ids = resolveTaskVoiceEmployeeIds(
      transcript: 'исполнитель Иванов, исполнитель Петров',
      employees: employees,
    );

    expect(ids, <String>['petrov']);
  });

  test('начнём заново может сразу принять новую задачу', () {
    final result = applyForemanVoiceSession(
      transcript:
          'Начнём заново, оси 9 12 б д, вид работ поставить опалубку, исполнитель Петров',
      now: now,
      employees: employees,
      initialDate: DateTime(2026, 8, 8),
      initialAxes: '1–2 / А–Б',
      initialWork: 'Старая работа',
      initialAssigneeIds: const <String>['ivanov'],
      allowDateChange: false,
      goalTask: false,
    );

    expect(result.resetRequested, isTrue);
    expect(result.axes, '9–12 / Б–Д');
    expect(result.work.toLowerCase(), contains('поставить опалубку'));
    expect(result.assigneeIds, <String>['petrov']);
  });

  test('строительная разговорная формулировка нормализуется', () {
    expect(
      normalizeTaskVoiceWork('там короче надо доармировать стену'),
      'Завершить армирование стену',
    );
    expect(
      normalizeTaskVoiceWork('добить опалубку колонн'),
      'Завершить опалубку колонн',
    );
    expect(
      normalizeTaskVoiceWork('залить плиту'),
      'Забетонировать плиту',
    );
  });

  test('одну речь можно разбить на несколько задач по сотрудникам', () {
    final drafts = parseForemanTaskVoiceBatch(
      transcript:
          'Иванову на завтра оси 5 8 а г закончить армирование стены. '
          'Петрову оси 9 12 б д поставить опалубку колонн.',
      now: now,
      employees: employees,
    );

    expect(drafts, hasLength(2));
    expect(drafts[0].assigneeIds, <String>['ivanov']);
    expect(drafts[0].axes, '5–8 / А–Г');
    expect(drafts[1].assigneeIds, <String>['petrov']);
    expect(drafts[1].axes, '9–12 / Б–Д');
    expect(drafts[1].date, DateTime(2026, 8, 9));
  });

  test('несколько исполнителей через явный маркер остаются одной задачей', () {
    final drafts = parseForemanTaskVoiceBatch(
      transcript:
          'На завтра оси 5 8 а г закончить армирование стены исполнители Иванов и Петров',
      now: now,
      employees: employees,
    );

    expect(drafts, isEmpty);
  });
}
