import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/models/employee.dart';
import 'package:skbs_app/screens/employees/employee_directory_controller.dart';

void main() {
  const murmansk = Employee(
    'Иванов Иван',
    'Бетонщик',
    'не отмечен',
    id: 'employee-1',
    phone: '+7 900 000-00-01',
    objectName: 'Мурманск',
    dailyRate: 6000,
  );
  const talnakhFired = Employee(
    'иванов иван',
    'Бетонщик',
    'не отмечен',
    id: 'employee-2',
    phone: '+7 (900) 000-00-01',
    objectName: 'Талнах',
    dailyRate: 6500,
    isActive: false,
  );
  const foreman = Employee(
    'Петров Пётр',
    'Прораб',
    'не отмечен',
    id: 'employee-3',
    objectName: 'Москва',
    dailyRate: 8000,
  );

  test('создаёт единый ключ по ФИО и телефону', () {
    expect(
      EmployeeDirectoryLogic.duplicateKey(murmansk),
      EmployeeDirectoryLogic.duplicateKey(talnakhFired),
    );
  });

  test('объединяет одного человека между объектами', () {
    final result = EmployeeDirectoryLogic.prepareEmployees(
      const <Employee>[talnakhFired, murmansk, foreman],
      query: '',
      collapseAcrossObjects: true,
      sortSelectedObject: false,
      sortDuplicateGroupsByObject: true,
      caseInsensitiveNameSort: false,
    );

    expect(result, hasLength(2));
    final ivanov = result.firstWhere(
      (employee) => employee.name.toLowerCase().contains('иванов'),
    );
    expect(ivanov.id, 'employee-1');
    expect(ivanov.objectName, 'Мурманск, Талнах');
    expect(ivanov.isActive, isTrue);
  });

  test('сохраняет порядок выбранного объекта для мобильного экрана', () {
    final result = EmployeeDirectoryLogic.prepareEmployees(
      const <Employee>[foreman, murmansk],
      query: '',
      collapseAcrossObjects: false,
      sortSelectedObject: false,
      sortDuplicateGroupsByObject: true,
      caseInsensitiveNameSort: false,
    );

    expect(result.map((employee) => employee.id), <String?>[
      'employee-3',
      'employee-1',
    ]);
  });

  test('сортирует выбранный объект для desktop-таблицы', () {
    final result = EmployeeDirectoryLogic.prepareEmployees(
      const <Employee>[foreman, murmansk],
      query: '',
      collapseAcrossObjects: false,
      sortSelectedObject: true,
      sortDuplicateGroupsByObject: false,
      caseInsensitiveNameSort: true,
    );

    expect(result.map((employee) => employee.id), <String?>[
      'employee-1',
      'employee-3',
    ]);
  });

  test('фильтрует по должности, телефону и объекту', () {
    final byPosition = EmployeeDirectoryLogic.prepareEmployees(
      const <Employee>[murmansk, foreman],
      query: 'прораб',
      collapseAcrossObjects: false,
      sortSelectedObject: false,
      sortDuplicateGroupsByObject: false,
      caseInsensitiveNameSort: false,
    );
    final byPhone = EmployeeDirectoryLogic.prepareEmployees(
      const <Employee>[murmansk, foreman],
      query: '900',
      collapseAcrossObjects: false,
      sortSelectedObject: false,
      sortDuplicateGroupsByObject: false,
      caseInsensitiveNameSort: false,
    );
    final byObject = EmployeeDirectoryLogic.prepareEmployees(
      const <Employee>[murmansk, foreman],
      query: 'мурманск',
      collapseAcrossObjects: false,
      sortSelectedObject: false,
      sortDuplicateGroupsByObject: false,
      caseInsensitiveNameSort: false,
    );

    expect(byPosition.single.id, 'employee-3');
    expect(byPhone.single.id, 'employee-1');
    expect(byObject.single.id, 'employee-1');
  });
}
