import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/models/employee.dart';
import 'package:skbs_app/models/monthly_timesheet_row.dart';
import 'package:skbs_app/screens/period_timesheet/period_timesheet_report.dart';

void main() {
  const activeEmployee = Employee(
    'Иванов Иван',
    'Бетонщик',
    'не отмечен',
    id: 'employee-1',
    objectName: 'Мурманск',
    dailyRate: 6000,
  );
  const firedCopy = Employee(
    '  иванов   иван ',
    'Бетонщик',
    'не отмечен',
    id: 'employee-2',
    objectName: 'Талнах',
    dailyRate: 6000,
    isActive: false,
  );

  test('объединяет одного сотрудника между объектами', () {
    final rows = PeriodTimesheetReport.collapseDuplicateRows(
      const <MonthlyTimesheetRow>[
        MonthlyTimesheetRow(
          employee: activeEmployee,
          shiftsByDay: <int, double>{1: 1, 2: 0.5},
          paid: 3000,
        ),
        MonthlyTimesheetRow(
          employee: firedCopy,
          shiftsByDay: <int, double>{1: 0.5, 3: 1},
          paid: 2000,
        ),
      ],
      collapseAcrossObjects: true,
    );

    expect(rows, hasLength(1));
    expect(rows.single.shiftForDay(1), 1.5);
    expect(rows.single.totalShifts, 3);
    expect(rows.single.paid, 5000);
    expect(rows.single.employee.objectName, 'Мурманск, Талнах');
    expect(rows.single.employee.isActive, isTrue);
  });

  test('не объединяет строки внутри выбранного объекта', () {
    final source = const <MonthlyTimesheetRow>[
      MonthlyTimesheetRow(
        employee: activeEmployee,
        shiftsByDay: <int, double>{1: 1},
        paid: 0,
      ),
      MonthlyTimesheetRow(
        employee: firedCopy,
        shiftsByDay: <int, double>{2: 1},
        paid: 0,
      ),
    ];

    final rows = PeriodTimesheetReport.collapseDuplicateRows(
      source,
      collapseAcrossObjects: false,
    );
    expect(rows, hasLength(2));
    expect(identical(rows, source), isFalse);
  });

  test('фильтрует только сотрудников со сменами', () {
    const other = Employee(
      'Петров Пётр',
      'Прораб',
      'не отмечен',
      objectName: 'Москва',
    );
    final rows = PeriodTimesheetReport.filterRows(
      const <MonthlyTimesheetRow>[
        MonthlyTimesheetRow(
          employee: activeEmployee,
          shiftsByDay: <int, double>{1: 1},
          paid: 0,
        ),
        MonthlyTimesheetRow(
          employee: other,
          shiftsByDay: <int, double>{},
          paid: 0,
        ),
      ],
      query: 'бетон',
    );

    expect(rows, hasLength(1));
    expect(rows.single.employee.name, 'Иванов Иван');
  });

  test('считает финансовый итог и статусы сотрудников', () {
    final summary = PeriodTimesheetReport.summarize(
      const <MonthlyTimesheetRow>[
        MonthlyTimesheetRow(
          employee: activeEmployee,
          shiftsByDay: <int, double>{1: 1},
          paid: 1000,
        ),
        MonthlyTimesheetRow(
          employee: firedCopy,
          shiftsByDay: <int, double>{1: 0.5},
          paid: 500,
        ),
      ],
    );

    expect(summary.employeeCount, 2);
    expect(summary.activeEmployeeCount, 1);
    expect(summary.firedEmployeeCount, 1);
    expect(summary.accrued, 9000);
    expect(summary.paid, 1500);
    expect(summary.balance, 7500);
  });
}
