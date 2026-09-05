import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/models/employee.dart';
import 'package:skbs_app/models/monthly_timesheet_row.dart';
import 'package:skbs_app/models/period_timesheet_row.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('employee prefers monthly salary and keeps legacy fallback', () {
    final monthly = Employee.fromSupabase(<String, dynamic>{
      'fio': 'Иванов Иван',
      'monthly_salary': 180000,
      'daily_rate': 6000,
    });
    final legacy = Employee.fromSupabase(<String, dynamic>{
      'fio': 'Петров Пётр',
      'daily_rate': 6000,
    });

    expect(monthly.monthlySalary, 180000);
    expect(legacy.monthlySalary, 6000);
  });

  test('salary accrual does not depend on timesheet shifts', () {
    const employee = Employee(
      'Иванов Иван',
      'Мастер',
      'не отмечен',
      monthlySalary: 180000,
    );
    const noShifts = PeriodTimesheetRow(
      employee: employee,
      shiftsByDate: <String, double>{},
    );
    const manyShifts = PeriodTimesheetRow(
      employee: employee,
      shiftsByDate: <String, double>{
        '2026-09-01': 1,
        '2026-09-02': 1.5,
        '2026-09-03': 1,
      },
    );
    const month = MonthlyTimesheetRow(
      employee: employee,
      shiftsByDay: <int, double>{1: 1, 2: 1, 3: 1},
      paid: 50000,
    );

    expect(noShifts.accrued, 180000);
    expect(manyShifts.accrued, 180000);
    expect(month.accrued, 180000);
    expect(month.balance, 130000);
  });

  test('employee forms use monthly salary wording and payload', () {
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
    expect(add, contains('monthlySalary: parseMonthlySalary()'));
    expect(edit, contains('monthlySalary: monthlySalary'));
    expect(ai, contains('monthlySalary: salary'));
    expect(repository, contains("'monthly_salary': monthlySalary"));
  });

  test('database migration builds monthly fund independent of attendance', () {
    final migration = source(
      'supabase/migrations/20260905114500_add_monthly_salary_fund.sql',
    );

    expect(migration, contains('add column if not exists monthly_salary'));
    expect(migration, contains('daily_rate * 30'));
    expect(migration, contains('round((daily_rate * 30)::numeric, -3)'));
    expect(migration, contains('employee.monthly_salary'));
    expect(
      migration,
      isNot(contains('sum(coalesce(attendance.shifts, 0) * employee.daily_rate)')),
    );
  });
}
