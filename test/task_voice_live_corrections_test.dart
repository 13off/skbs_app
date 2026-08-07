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

  test('последняя явная дата заменяет предыдущую во время той же записи', () {
    final result = parseForemanTaskVoice(
      transcript:
          'Дата завтра оси один два бэ вид работ армирование исполнитель Дементьев нет дата послезавтра',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.date, DateTime(2026, 8, 9));
    expect(result.axes, '1–2 / Б');
    expect(result.work, 'Армирование');
  });

  test('последние оси заменяют предыдущие во время той же записи', () {
    final result = parseForemanTaskVoice(
      transcript:
          'Дата завтра оси один два бэ вид работ армирование исполнитель Дементьев нет оси пять восемь а г',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.date, DateTime(2026, 8, 8));
    expect(result.axes, '5–8 / А–Г');
    expect(result.work, 'Армирование');
  });

  test('последний вид работ заменяет предыдущий и не захватывает соседние поля', () {
    final result = parseForemanTaskVoice(
      transcript:
          'Дата завтра оси один два бэ вид работ армирование исполнитель Дементьев нет вид работ бетонирование дата послезавтра',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.date, DateTime(2026, 8, 9));
    expect(result.axes, '1–2 / Б');
    expect(result.work, 'Бетонирование');
  });

  test('в одной записи можно последовательно исправить три поля', () {
    final result = parseForemanTaskVoice(
      transcript:
          'Дата завтра оси один два бэ вид работ армирование исполнитель Дементьев нет дата послезавтра оси семь десять бэ дэ вид работ бетонирование',
      now: DateTime(2026, 8, 7),
      employees: employees,
    );

    expect(result.date, DateTime(2026, 8, 9));
    expect(result.axes, '7–10 / Б–Д');
    expect(result.work, 'Бетонирование');
  });
}
