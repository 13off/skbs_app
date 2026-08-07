import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_parser.dart';
import 'package:skbs_app/models/employee.dart';

void main() {
  final employees = <Employee>[
    const Employee(
      'Иванов Иван Иванович',
      'Бетонщик',
      '',
      id: 'ivanov',
      objectName: 'Мурманск',
    ),
    const Employee(
      'Ахмедов Руслан Маратович',
      'Арматурщик',
      '',
      id: 'akhmedov',
      objectName: 'Мурманск',
    ),
    const Employee(
      'Петров Сергей Николаевич',
      'Бетонщик',
      '',
      id: 'petrov',
      objectName: 'Мурманск',
    ),
  ];

  test('разбирает дату оси задачу и нескольких исполнителей', () {
    final result = parseTaskVoice(
      transcript:
          'На завтра, оси 5-8 А-Г, закончить армирование стены, Иванов и Ахмедов',
      now: DateTime(2026, 8, 7, 11, 30),
      employees: employees,
    );

    expect(result.date, DateTime(2026, 8, 8));
    expect(result.axes, '5–8 / А–Г');
    expect(result.work, 'Закончить армирование стены');
    expect(result.assigneeIds, <String>['ivanov', 'akhmedov']);
  });

  test('понимает явную дату и фамилию в дательном падеже', () {
    final result = parseTaskVoice(
      transcript: 'На 12.08.2026 оси 1 по 4 А по Б сделать опалубку Петрову',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.date, DateTime(2026, 8, 12));
    expect(result.axes, '1–4 / А–Б');
    expect(result.work, 'Сделать опалубку');
    expect(result.assigneeIds, <String>['petrov']);
  });

  test('понимает дату словами', () {
    final result = parseTaskVoice(
      transcript: 'На 10 августа оси 3-5 выполнить бетонирование Иванов',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.date, DateTime(2026, 8, 10));
    expect(result.axes, '3–5');
    expect(result.work, 'Выполнить бетонирование');
    expect(result.assigneeIds, <String>['ivanov']);
  });

  test('не выдумывает исполнителя которого нет на объекте', () {
    final result = parseTaskVoice(
      transcript: 'Завтра оси 2-3 закончить стену Сидоров',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.assigneeIds, isEmpty);
    expect(result.work, contains('Сидоров'));
  });
}
