import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/models/employee.dart';
import 'package:skbs_app/models/monthly_salary_calculator.dart';
import 'package:skbs_app/models/monthly_timesheet_row.dart';
import 'package:skbs_app/models/period_timesheet_row.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('employee prefers monthly salary and reads hidden timesheet exclusion', () {
    final monthly = Employee.fromSupabase(<String, dynamic>{
      'fio': 'Иванов Иван',
      'monthly_salary': 180000,
      'daily_rate': 180000,
      'timesheet_excluded': true,
    });
    final legacy = Employee.fromSupabase(<String, dynamic>{
      'fio': 'Петров Пётр',
      'daily_rate': 160000,
    });

    expect(monthly.monthlySalary, 180000);
    expect(monthly.timesheetExcluded, isTrue);
    expect(legacy.monthlySalary, 160000);
    expect(legacy.timesheetExcluded, isFalse);
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

  test('monthly salary never multiplies the monthly fund by shifts', () {
    final accrued = calculateMonthlySalaryAccrued(
      monthlySalary: 120000,
      countedShifts: 22.4,
    );

    expect(accrued, closeTo(89600, 0.001));
    expect(accrued, isNot(closeTo(2688000, 0.001)));
  });

  test('all ordinary timesheet rows are prorated from actual shifts', () {
    const employee = Employee(
      'Иванов Иван',
      'Мастер',
      'не отмечен',
      monthlySalary: 160000,
    );
    final shifts = <String, double>{
      for (var day = 1; day <= 25; day++)
        '2026-09-${day.toString().padLeft(2, '0')}': 1,
    };
    final period = PeriodTimesheetRow(employee: employee, shiftsByDate: shifts);
    const month = MonthlyTimesheetRow(
      employee: employee,
      shiftsByDay: <int, double>{1: 1, 2: 1},
      paid: 50000,
    );

    expect(period.totalShifts, 25);
    expect(period.accrued, closeTo(133333.333333, 0.001));
    expect(month.accrued, closeTo(10666.666666, 0.001));
  });

  test('employee forms no longer expose ignore-timesheet control', () {
    final add = source(
      'lib/features/employees/presentation/screens/add_employee_screen.dart',
    );
    final edit = source('lib/screens/edit_employee_screen.dart');
    final ai = source(
      'lib/features/ai/presentation/ai_employee_draft_screen.dart',
    );
    final repository = source('lib/data/employee_repository.dart');
    final calculator = source('lib/models/monthly_salary_calculator.dart');

    for (final value in <String>[add, edit, ai]) {
      expect(value, contains('Зарплата в месяц'));
      expect(value, isNot(contains('Ставка за смену')));
      expect(value, isNot(contains('Не учитывать табель')));
      expect(value, isNot(contains('ignoreTimesheet')));
    }
    expect(repository, isNot(contains("'ignore_timesheet':")));
    expect(calculator, isNot(contains('ignoreTimesheet')));
  });

  test('system-only timesheet exclusion is not editable through employee CRUD', () {
    final repository = source('lib/data/employee_repository.dart');
    final employee = source('lib/models/employee.dart');
    final offline = source('lib/data/offline_master_repository.dart');
    final attendance = source('lib/data/attendance_repository.dart');

    expect(employee, contains('final bool timesheetExcluded;'));
    expect(employee, contains("json['timesheet_excluded']"));
    expect(repository, isNot(contains('bool timesheetExcluded =')));
    expect(repository, isNot(contains('bool? timesheetExcluded')));
    expect(offline, contains('forTimesheet'));
    expect(offline, contains('!employee.timesheetExcluded'));
    expect(attendance, contains('employee.timesheetExcluded'));
  });

  test('developer restriction uses server attendance permission', () {
    final panel = source(
      'lib/features/developer/presentation/developer_panel_screen_legacy.dart',
    );

    expect(panel, contains("_attendanceEditPermission = 'attendance.edit'"));
    expect(panel, contains('RolePermissionRepository.saveOverride'));
    expect(panel, contains('Разрешить прорабу редактировать табель'));
  });
}
