import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_report_row.dart';
import '../models/employee.dart';
import '../models/monthly_timesheet_row.dart';
import '../models/period_timesheet_row.dart';
import 'employee_repository.dart';

class AttendanceRepository {
  static final _client = Supabase.instance.client;

  static String dateKey(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    final month = cleanDate.month.toString().padLeft(2, '0');
    final day = cleanDate.day.toString().padLeft(2, '0');

    return '${cleanDate.year}-$month-$day';
  }

  static String? cleanObjectName(String? objectName) {
    final clean = objectName?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  static Future<Map<String, double>> fetchShiftValuesForDate(
    DateTime date, {
    String? objectName,
  }) async {
    final cleanObject = cleanObjectName(objectName);

    final rows = cleanObject == null
        ? await _client
              .from('attendance')
              .select('employee_id, shifts, object_name')
              .eq('work_date', dateKey(date))
        : await _client
              .from('attendance')
              .select('employee_id, shifts, object_name')
              .eq('work_date', dateKey(date))
              .eq('object_name', cleanObject);

    final values = <String, double>{};

    for (final row in rows) {
      final employeeId = row['employee_id']?.toString();

      if (employeeId == null) continue;

      values[employeeId] = _toDouble(row['shifts']);
    }

    return values;
  }

  static Future<Set<String>> fetchWorkedEmployeeIds(
    DateTime date, {
    String? objectName,
  }) async {
    final values = await fetchShiftValuesForDate(date, objectName: objectName);

    final ids = <String>{};

    values.forEach((employeeId, shifts) {
      if (shifts > 0) {
        ids.add(employeeId);
      }
    });

    return ids;
  }

  static Future<void> saveTimesheet({
    required DateTime date,
    required List<Employee> employees,
    required Map<String, double> shiftValuesByEmployeeId,
  }) async {
    final rows = <Map<String, dynamic>>[];

    for (final employee in employees) {
      if (employee.id == null) continue;

      final shifts = shiftValuesByEmployeeId[employee.id!] ?? 0;

      rows.add({
        'work_date': dateKey(date),
        'employee_id': employee.id,
        'object_name': employee.objectName,
        'status': shifts > 0 ? 'worked' : 'no_show',
        'shifts': shifts,
        'marked_by': 'Илья',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    if (rows.isEmpty) return;

    await _client
        .from('attendance')
        .upsert(rows, onConflict: 'work_date,employee_id');
  }

  static Future<List<AttendanceReportRow>> fetchReportForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? objectName,
    bool includeFired = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);

    final employees = await EmployeeRepository.fetchEmployees(
      objectName: cleanObject,
      includeFired: includeFired,
    );

    final employeesById = <String, Employee>{};

    for (final employee in employees) {
      if (employee.id != null) {
        employeesById[employee.id!] = employee;
      }
    }

    final rows = cleanObject == null
        ? await _client
              .from('attendance')
              .select('employee_id, shifts, object_name')
              .eq('status', 'worked')
              .gte('work_date', dateKey(startDate))
              .lte('work_date', dateKey(endDate))
        : await _client
              .from('attendance')
              .select('employee_id, shifts, object_name')
              .eq('status', 'worked')
              .gte('work_date', dateKey(startDate))
              .lte('work_date', dateKey(endDate))
              .eq('object_name', cleanObject);

    final totals = <String, _AttendanceTotals>{};

    for (final row in rows) {
      final employeeId = row['employee_id']?.toString();

      if (employeeId == null) continue;

      final currentTotals = totals[employeeId] ?? _AttendanceTotals();

      currentTotals.shifts += _toDouble(row['shifts']);

      totals[employeeId] = currentTotals;
    }

    final reportRows = <AttendanceReportRow>[];

    totals.forEach((employeeId, total) {
      final employee = employeesById[employeeId];

      if (employee == null) return;

      reportRows.add(
        AttendanceReportRow(
          employeeId: employeeId,
          employeeName: employee.name,
          position: employee.position,
          dailyRate: employee.dailyRate,
          shifts: total.shifts,
        ),
      );
    });

    reportRows.sort((a, b) => a.employeeName.compareTo(b.employeeName));

    return reportRows;
  }

  static Future<List<MonthlyTimesheetRow>> fetchMonthlyTimesheet({
    required int year,
    required int month,
    String? objectName,
    bool includeFired = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);

    final employees = await EmployeeRepository.fetchEmployees(
      objectName: cleanObject,
      includeFired: includeFired,
    );

    final firstDate = DateTime(year, month, 1);
    final lastDate = DateTime(year, month + 1, 0);

    final attendanceRows = cleanObject == null
        ? await _client
              .from('attendance')
              .select('employee_id, work_date, shifts, object_name')
              .gte('work_date', dateKey(firstDate))
              .lte('work_date', dateKey(lastDate))
        : await _client
              .from('attendance')
              .select('employee_id, work_date, shifts, object_name')
              .gte('work_date', dateKey(firstDate))
              .lte('work_date', dateKey(lastDate))
              .eq('object_name', cleanObject);

    final shiftsByEmployeeId = <String, Map<int, double>>{};

    for (final row in attendanceRows) {
      final employeeId = row['employee_id']?.toString();
      final workDateText = row['work_date']?.toString();

      if (employeeId == null || workDateText == null) continue;

      final workDate = DateTime.tryParse(workDateText);

      if (workDate == null) continue;

      final employeeDays = shiftsByEmployeeId.putIfAbsent(
        employeeId,
        () => <int, double>{},
      );

      employeeDays[workDate.day] = _toDouble(row['shifts']);
    }

    final paymentRows = await _client
        .from('payments')
        .select('employee_id, amount')
        .eq('period_year', year)
        .eq('period_month', month);

    final paidByEmployeeId = <String, double>{};

    for (final row in paymentRows) {
      final employeeId = row['employee_id']?.toString();

      if (employeeId == null) continue;

      paidByEmployeeId[employeeId] =
          (paidByEmployeeId[employeeId] ?? 0.0) + _toDouble(row['amount']);
    }

    return employees.map((employee) {
      final employeeId = employee.id;

      return MonthlyTimesheetRow(
        employee: employee,
        shiftsByDay: employeeId == null
            ? <int, double>{}
            : shiftsByEmployeeId[employeeId] ?? <int, double>{},
        paid: employeeId == null ? 0.0 : paidByEmployeeId[employeeId] ?? 0.0,
      );
    }).toList();
  }

  static Future<List<PeriodTimesheetRow>> fetchPeriodTimesheet({
    required DateTime startDate,
    required DateTime endDate,
    String? objectName,
    bool includeFired = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);

    final employees = await EmployeeRepository.fetchEmployees(
      objectName: cleanObject,
      includeFired: includeFired,
    );

    final rows = cleanObject == null
        ? await _client
              .from('attendance')
              .select('employee_id, work_date, shifts, object_name')
              .gte('work_date', dateKey(startDate))
              .lte('work_date', dateKey(endDate))
        : await _client
              .from('attendance')
              .select('employee_id, work_date, shifts, object_name')
              .gte('work_date', dateKey(startDate))
              .lte('work_date', dateKey(endDate))
              .eq('object_name', cleanObject);

    final shiftsByEmployeeId = <String, Map<String, double>>{};

    for (final row in rows) {
      final employeeId = row['employee_id']?.toString();
      final workDateText = row['work_date']?.toString();

      if (employeeId == null || workDateText == null) continue;

      final employeeDates = shiftsByEmployeeId.putIfAbsent(
        employeeId,
        () => <String, double>{},
      );

      employeeDates[workDateText] = _toDouble(row['shifts']);
    }

    return employees.map((employee) {
      final employeeId = employee.id;

      return PeriodTimesheetRow(
        employee: employee,
        shiftsByDate: employeeId == null
            ? <String, double>{}
            : shiftsByEmployeeId[employeeId] ?? <String, double>{},
      );
    }).toList();
  }
}

class _AttendanceTotals {
  double shifts = 0;
}
