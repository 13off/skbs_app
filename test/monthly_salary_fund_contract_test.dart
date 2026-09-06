import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/models/employee.dart';
import 'package:skbs_app/models/monthly_salary_calculator.dart';
import 'package:skbs_app/models/monthly_timesheet_row.dart';
import 'package:skbs_app/models/period_timesheet_row.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('employee prefers monthly salary and keeps compatibility fallback', () {
    final monthly = Employee.fromSupabase(<String, dynamic>{
      'fio': 'Иванов Иван',
      'monthly_salary': 180000,
      'daily_rate': 180000,
      'ignore_timesheet': true,
    });
    final legacy = Employee.fromSupabase(<String, dynamic>{
      'fio': 'Петров Пётр',
      'daily_rate': 160000,
    });

    expect(monthly.monthlySalary, 180000);
    expect(monthly.ignoreTimesheet, isTrue);
    expect(legacy.monthlySalary, 160000);
    expect(legacy.ignoreTimesheet, isFalse);
  });

  test('monthly salary uses a 30-shift norm', () {
    expect(monthlySalaryShiftNorm, 30);
    expect(
      calculateMonthlySalaryAccrued(
        monthlySalary: 160000,
        countedShifts: 30,
      ),
      closeTo(160000, 0.001),
    );
    expect(
      calculateMonthlySalaryAccrued(
        monthlySalary: 160000,
        countedShifts: 25,
      ),
      closeTo(133333.333333, 0.001),
    );
    expect(
      calculateMonthlySalaryAccrued(
        monthlySalary: 160000,
        countedShifts: 0,
      ),
      0,
    );
  });

  test('ignore timesheet keeps full monthly salary', () {
    const employee = Employee(
      'Иванов Иван',
      'Мастер',
      'не отмечен',
      monthlySalary: 160000,
      ignoreTimesheet: true,
    );
    const period = PeriodTimesheetRow(
      employee: employee,
      shiftsByDate: <String, double>{
        '2026-09-01': 1,
        '2026-09-02': 1,
      },
    );
    const month = MonthlyTimesheetRow(
      employee: employee,
      shiftsByDay: <int, double>{1: 1, 2: 1},
      paid: 50000,
    );

    expect(period.accrued, 160000);
    expect(month.accrued, 160000);
    expect(month.balance, 110000);
  });

  test('timesheet rows prorate ordinary monthly salary', () {
    const employee = Employee(
      'Иванов Иван',
      'Мастер',
      'не отмечен',
      monthlySalary: 160000,
    );
    final shifts = <String, double>{
      for (var day = 1; day <= 25; day++) '2026-09-${day.toString().padLeft(2, '0')}': 1,
    };
    final row = PeriodTimesheetRow(employee: employee, shiftsByDate: shifts);

    expect(row.totalShifts, 25);
    expect(row.accrued, closeTo(133333.333333, 0.001));
  });

  test('employee forms use monthly salary wording and timesheet switch', () {
    final add = source(
      'lib/features/employees/presentation/screens/add_employee_screen.dart',
    );
    final edit = source('lib/screens/edit_employee_screen.dart');
    final ai = source('lib/features/ai/presentation/ai_employee_draft_screen.dart');
    final repository = source('lib/data/employee_repository.dart');

    for (final value in <String>[add, edit, ai]) {
      expect(value, contains('Зарплата в месяц'));
      expect(value, isNot(contains('Ставка за смену')));
    }
    expect(add, contains('Не учитывать табель'));
    expect(edit, contains('Не учитывать табель'));
    expect(add, contains('ignoreTimesheet: ignoreTimesheet'));
    expect(edit, contains('ignoreTimesheet: ignoreTimesheet'));
    expect(repository, contains("'monthly_salary': monthlySalary"));
    expect(repository, contains("'ignore_timesheet': ignoreTimesheet"));
  });

  test('developer restriction uses server attendance permission', () {
    final panel = source(
      'lib/features/developer/presentation/developer_panel_screen_legacy.dart',
    );

    expect(panel, contains("_attendanceEditPermission = 'attendance.edit'"));
    expect(panel, contains('RolePermissionRepository.saveOverride'));
    expect(panel, contains('Разрешить прорабу редактировать табель'));
  });

  test('database migration prorates monthly salary and stores override flag', () {
    final migration = source(
      'supabase/migrations/20260906160000_prorate_monthly_salary_by_timesheet.sql',
    );

    expect(migration, contains('add column if not exists monthly_salary'));
    expect(migration, contains('add column if not exists ignore_timesheet'));
    expect(migration, contains('employee.monthly_salary / 30.0'));
    expect(migration, contains('when employee.ignore_timesheet then'));
    expect(migration, contains('daily_rate = monthly_salary'));
  });
}
