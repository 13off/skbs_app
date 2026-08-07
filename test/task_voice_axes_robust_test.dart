import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_parser_robust.dart';
import 'package:skbs_app/models/employee.dart';

void main() {
  final employees = <Employee>[
    const Employee(
      'Дементьев Борис Викторович',
      'Бетонщик',
      '',
      id: 'dementev',
      objectName: 'Мурманск',
    ),
  ];

  test('чинит реальную фразу с экрана: один два 6 означает 1–2 / Б', () {
    final result = parseForemanTaskVoice(
      transcript:
          'Задачи на сегодня оси один два 6 вид работ армирование исполнителей Дементьев',
      now: DateTime(2026, 8, 7, 14, 19),
      employees: employees,
    );

    expect(result.date, DateTime(2026, 8, 7));
    expect(result.axes, '1–2 / Б');
    expect(result.work, 'Армирование');
    expect(result.assigneeIds, <String>['dementev']);
  });

  test('понимает числовые оси словами и буквенный диапазон', () {
    final result = parseForemanTaskVoice(
      transcript:
          'На завтра оси пять восемь а г закончить армирование стены Дементьев',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.axes, '5–8 / А–Г');
    expect(result.date, DateTime(2026, 8, 8));
    expect(result.assigneeIds, <String>['dementev']);
  });

  test('понимает формулировку с первой по пятую от А до Г', () {
    final result = parseForemanTaskVoice(
      transcript:
          'Сегодня оси с первой по пятую от а до г вид работ опалубка исполнители Дементьев',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.axes, '1–5 / А–Г');
    expect(result.work, 'Опалубка');
  });

  test('не ломает привычный формат цифрами', () {
    final result = parseForemanTaskVoice(
      transcript: 'На завтра оси 5-8 А-Г закончить стену Дементьев',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.axes, '5–8 / А–Г');
    expect(result.assigneeIds, <String>['dementev']);
  });
}
