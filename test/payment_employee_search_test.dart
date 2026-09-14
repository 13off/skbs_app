import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/models/employee.dart';
import 'package:skbs_app/screens/add_payment_screen.dart';

void main() {
  const employees = <Employee>[
    Employee('Иванов Сергей Петрович', 'Бетонщик', 'работает'),
    Employee('Петров Иван Сергеевич', 'Арматурщик', 'работает'),
    Employee('Сидоров Алексей Иванович', 'Мастер', 'работает'),
  ];

  test('поиск сотрудника находит по началу фамилии, имени и отчеству', () {
    expect(
      searchPaymentEmployees(employees: employees, query: 'Ива')
          .map((employee) => employee.name),
      containsAll(<String>[
        'Иванов Сергей Петрович',
        'Петров Иван Сергеевич',
      ]),
    );
    expect(
      searchPaymentEmployees(employees: employees, query: 'Алекс')
          .single
          .name,
      'Сидоров Алексей Иванович',
    );
  });

  test('пустой поиск показывает сотрудников в алфавитном порядке', () {
    final result = searchPaymentEmployees(
      employees: employees.reversed,
      query: '',
    );
    expect(result.first.name, 'Иванов Сергей Петрович');
    expect(result.length, 3);
  });
}
