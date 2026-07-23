import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('period attendance report loads employees and shifts together', () {
    final source = File('lib/data/attendance_repository.dart').readAsStringSync();
    final start = source.indexOf(
      'static Future<List<AttendanceReportRow>> _fetchReportForPeriod',
    );
    final end = source.indexOf(
      'static Future<List<MonthlyTimesheetRow>> fetchMonthlyTimesheet',
      start,
    );
    final method = source.substring(start, end);

    expect(method, contains('final data = await Future.wait<dynamic>(['));
    expect(method, contains('EmployeeRepository.fetchEmployees('));
    expect(method, contains('_fetchAttendanceRows('));
    expect(method, contains('final employees = data[0] as List<Employee>;'));
    expect(
      method,
      contains('final rows = data[1] as List<Map<String, dynamic>>;'),
    );
  });

  test('monthly timesheet loads employees, attendance and payments together', () {
    final source = File('lib/data/attendance_repository.dart').readAsStringSync();
    final start = source.indexOf(
      'static Future<List<MonthlyTimesheetRow>> _fetchMonthlyTimesheet',
    );
    final end = source.indexOf(
      'static Future<MonthlyTimesheetRow> fetchMonthlyTimesheetForEmployee',
      start,
    );
    final method = source.substring(start, end);

    expect(method, contains('final data = await Future.wait<dynamic>(['));
    expect(method, contains('EmployeeRepository.fetchEmployees('));
    expect(method, contains('_fetchAttendanceRows('));
    expect(method, contains(".from('payments')"));
    expect(method, contains('final employees = data[0] as List<Employee>;'));
    expect(
      method,
      contains('final attendanceRows = data[1] as List<Map<String, dynamic>>;'),
    );
    expect(method, contains('final paymentRows = data[2] as List<dynamic>;'));
  });

  test('employee month and arbitrary period also avoid serial reads', () {
    final source = File('lib/data/attendance_repository.dart').readAsStringSync();

    final employeeStart = source.indexOf(
      'static Future<MonthlyTimesheetRow> _fetchMonthlyTimesheetForEmployee',
    );
    final employeeEnd = source.indexOf(
      'static Future<List<PeriodTimesheetRow>> fetchPeriodTimesheet',
      employeeStart,
    );
    final employeeMethod = source.substring(employeeStart, employeeEnd);
    expect(employeeMethod, contains('final data = await Future.wait<dynamic>(['));
    expect(employeeMethod, contains('_fetchAttendanceRows('));
    expect(employeeMethod, contains(".from('payments')"));

    final periodStart = source.indexOf(
      'static Future<List<PeriodTimesheetRow>> _fetchPeriodTimesheet',
    );
    final periodMethod = source.substring(periodStart);
    expect(periodMethod, contains('final data = await Future.wait<dynamic>(['));
    expect(periodMethod, contains('EmployeeRepository.fetchEmployees('));
    expect(periodMethod, contains('_fetchAttendanceRows('));
  });

  test('caches and result assembly remain in place', () {
    final source = File('lib/data/attendance_repository.dart').readAsStringSync();

    expect(source, contains('_attendanceReportCache[cacheKey]'));
    expect(source, contains('_monthlyTimesheetCache[cacheKey]'));
    expect(source, contains('_employeeMonthlyTimesheetCache[cacheKey]'));
    expect(source, contains('_periodTimesheetCache[cacheKey]'));
    expect(source, contains('AttendanceReportRow('));
    expect(source, contains('MonthlyTimesheetRow('));
    expect(source, contains('PeriodTimesheetRow('));
  });
}
