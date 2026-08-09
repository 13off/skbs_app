import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_active_field.dart';
import 'package:skbs_app/features/tasks/voice/task_voice_dictionaries.dart';
import 'package:skbs_app/models/employee.dart';

void main() {
  const employees = <Employee>[
    Employee('Иванов Иван', 'Бетонщик', 'работает', id: '1'),
    Employee('Петров Петр', 'Арматурщик', 'работает', id: '2'),
  ];

  test('словарь исполнителя приоритизирует реальные фамилии', () {
    final hints = buildTaskVoiceContextHints(
      activeField: TaskVoiceField.assignees,
      employees: employees,
    );

    expect(hints, contains('иванов'));
    expect(hints, contains('петров'));
    expect(hints, contains('иван'));
    expect(hints, isNot(contains('бетонирование')));
    expect(hints, isNot(contains('бэгэ')));
  });

  test('словарь вида работ содержит строительную лексику без фамилий', () {
    final hints = buildTaskVoiceContextHints(
      activeField: TaskVoiceField.work,
      employees: employees,
    );

    expect(hints, contains('бетонирование'));
    expect(hints, contains('вязка арматуры'));
    expect(hints, contains('распалубка'));
    expect(hints, contains('гидроизоляция'));
    expect(hints, isNot(contains('иванов')));
  });

  test('словарь осей содержит буквенные и фонетические варианты', () {
    final hints = buildTaskVoiceContextHints(
      activeField: TaskVoiceField.axes,
      employees: employees,
    );

    expect(hints, contains('бэ'));
    expect(hints, contains('беги'));
    expect(hints, contains('борис'));
    expect(hints, contains('григорий'));
    expect(hints, contains('восемь'));
    expect(hints, isNot(contains('бетонирование')));
    expect(hints, isNot(contains('иванов')));
  });

  test('словарь даты не загрязняется строительными терминами', () {
    final hints = buildTaskVoiceContextHints(
      activeField: TaskVoiceField.date,
      employees: employees,
    );

    expect(hints, contains('завтра'));
    expect(hints, contains('понедельник'));
    expect(hints, contains('август'));
    expect(hints, isNot(contains('бетонирование')));
    expect(hints, isNot(contains('иванов')));
  });

  test('до выбора поля словарь остается ограниченным', () {
    final hints = buildTaskVoiceContextHints(
      activeField: null,
      employees: employees,
    );

    expect(hints, containsAll(<String>['дата', 'оси', 'вид работ', 'исполнитель']));
    expect(hints, contains('бетонирование'));
    expect(hints, contains('иванов'));
    expect(hints.length, lessThanOrEqualTo(150));
  });

  test('короткая подсказка бе не совпадает с бетонированием', () {
    expect(
      scoreTaskVoiceRecognitionHints('бетонирование стены', const <String>['бе']),
      0,
    );
    expect(
      scoreTaskVoiceRecognitionHints('бе гэ', const <String>['бе', 'гэ']),
      greaterThan(0),
    );
  });

  test('многословная подсказка считается только как отдельная фраза', () {
    expect(
      scoreTaskVoiceRecognitionHints(
        'монтаж опалубки стены',
        const <String>['монтаж опалубки'],
      ),
      greaterThan(0),
    );
    expect(
      scoreTaskVoiceRecognitionHints(
        'демонтаж опалубки',
        const <String>['монтаж опалубки'],
      ),
      0,
    );
  });
}
