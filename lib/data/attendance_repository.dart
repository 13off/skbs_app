import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_report_row.dart';
import '../models/employee.dart';
import '../models/monthly_timesheet_row.dart';
import '../models/period_timesheet_row.dart';
import 'employee_repository.dart';

class AttendanceRepository {
  static final _client = Supabase.instance.client;

  static const Duration _shortCacheTtl = Duration(seconds: 15);
  static const Duration _reportCacheTtl = Duration(seconds: 25);

  static final Map<String, _ShiftValuesCacheEntry> _shiftValuesCache = {};
  static final Map<String, _MonthlyTimesheetCacheEntry> _monthlyTimesheetCache =
      {};
  static final Map<String, _EmployeeMonthlyTimesheetCacheEntry>
  _employeeMonthlyTimesheetCache = {};
  static final Map<String, _PeriodTimesheetCacheEntry> _periodTimesheetCache =
      {};
  static final Map<String, _AttendanceReportCacheEntry> _attendanceReportCache =
      {};

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

  static void clearCache() {
    _shiftValuesCache.clear();
    _monthlyTimesheetCache.clear();
    _employeeMonthlyTimesheetCache.clear();
    _periodTimesheetCache.clear();
    _attendanceReportCache.clear();
  }

  static String _objectCachePart(String? objectName) {
    return cleanObjectName(objectName) ?? '__all__';
  }

  static String _dayCacheKey({
    required DateTime date,
    required String? objectName,
  }) {
    return '${dateKey(date)}::${_objectCachePart(objectName)}';
  }

  static String _monthCacheKey({
    required int year,
    required int month,
    required String? objectName,
    required bool includeFired,
  }) {
    final firedPart = includeFired ? 'with_fired' : 'active_only';

    return '$year::$month::${_objectCachePart(objectName)}::$firedPart';
  }

  static String _employeeMonthCacheKey({
    required String employeeId,
    required int year,
    required int month,
  }) {
    return '$employeeId::$year::$month';
  }

  static String _periodCacheKey({
    required DateTime startDate,
    required DateTime endDate,
    required String? objectName,
    required bool includeFired,
  }) {
    final firedPart = includeFired ? 'with_fired' : 'active_only';

    return '${dateKey(startDate)}::${dateKey(endDate)}::${_objectCachePart(objectName)}::$firedPart';
  }

  static bool _isFresh(DateTime createdAt, Duration ttl) {
    return DateTime.now().difference(createdAt) < ttl;
  }

  static Map<String, double> _copyShiftValues(Map<String, double> values) {
    return Map<String, double>.from(values);
  }

  static List<MonthlyTimesheetRow> _copyMonthlyRows(
    List<MonthlyTimesheetRow> rows,
  ) {
    return List<MonthlyTimesheetRow>.from(rows);
  }

  static List<PeriodTimesheetRow> _copyPeriodRows(
    List<PeriodTimesheetRow> rows,
  ) {
    return List<PeriodTimesheetRow>.from(rows);
  }

  static List<AttendanceReportRow> _copyReportRows(
    List<AttendanceReportRow> rows,
  ) {
    return List<AttendanceReportRow>.from(rows);
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
    bool forceRefresh = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);
    final cacheKey = _dayCacheKey(date: date, objectName: cleanObject);
    final cached = _shiftValuesCache[cacheKey];

    if (!forceRefresh &&
        cached != null &&
        _isFresh(cached.createdAt, _shortCacheTtl)) {
      return _copyShiftValues(cached.values);
    }

    final rows = cleanObject == null
        ? await _client
              .from('attendance')
              .select('employee_id, shifts')
              .eq('work_date', dateKey(date))
        : await _client
              .from('attendance')
              .select('employee_id, shifts')
              .eq('work_date', dateKey(date))
              .eq('object_name', cleanObject);

    final values = <String, double>{};

    for (final row in rows) {
      final employeeId = row['employee_id']?.toString();

      if (employeeId == null) continue;

      values[employeeId] = _toDouble(row['shifts']);
    }

    _shiftValuesCache[cacheKey] = _ShiftValuesCacheEntry(
      values: _copyShiftValues(values),
      createdAt: DateTime.now(),
    );

    return _copyShiftValues(values);
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
    Map<String, double>? originalShiftValuesByEmployeeId,
  }) async {
    final rows = <Map<String, dynamic>>[];
    final workDate = dateKey(date);
    final now = DateTime.now().toUtc().toIso8601String();

    for (final employee in employees) {
      final employeeId = employee.id;

      if (employeeId == null) continue;

      final shifts = shiftValuesByEmployeeId[employeeId] ?? 0.0;

      if (originalShiftValuesByEmployeeId != null) {
        final oldShifts = originalShiftValuesByEmployeeId[employeeId] ?? 0.0;

        if (oldShifts == shifts) continue;
      }

      rows.add({
        'work_date': workDate,
        'employee_id': employeeId,
        'object_name': employee.objectName,
        'status': shifts > 0 ? 'worked' : 'no_show',
        'shifts': shifts,
        'marked_by': 'Илья',
        'updated_at': now,
      });
    }

    if (rows.isEmpty) return;

    await _client
        .from('attendance')
        .upsert(rows, onConflict: 'work_date,employee_id');

    clearCache();
  }

  static Future<List<AttendanceReportRow>> fetchReportForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? objectName,
    bool includeFired = false,
    bool forceRefresh = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);
    final cacheKey = _periodCacheKey(
      startDate: startDate,
      endDate: endDate,
      objectName: cleanObject,
      includeFired: includeFired,
    );
    final cached = _attendanceReportCache[cacheKey];

    if (!forceRefresh &&
        cached != null &&
        _isFresh(cached.createdAt, _reportCacheTtl)) {
      return _copyReportRows(cached.rows);
    }

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
              .select('employee_id, shifts')
              .eq('status', 'worked')
              .gte('work_date', dateKey(startDate))
              .lte('work_date', dateKey(endDate))
        : await _client
              .from('attendance')
              .select('employee_id, shifts')
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

    _attendanceReportCache[cacheKey] = _AttendanceReportCacheEntry(
      rows: _copyReportRows(reportRows),
      createdAt: DateTime.now(),
    );

    return _copyReportRows(reportRows);
  }

  static Future<List<MonthlyTimesheetRow>> fetchMonthlyTimesheet({
    required int year,
    required int month,
    String? objectName,
    bool includeFired = false,
    bool forceRefresh = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);
    final cacheKey = _monthCacheKey(
      year: year,
      month: month,
      objectName: cleanObject,
      includeFired: includeFired,
    );
    final cached = _monthlyTimesheetCache[cacheKey];

    if (!forceRefresh &&
        cached != null &&
        _isFresh(cached.createdAt, _reportCacheTtl)) {
      return _copyMonthlyRows(cached.rows);
    }

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

    final result = employees.map((employee) {
      final employeeId = employee.id;

      return MonthlyTimesheetRow(
        employee: employee,
        shiftsByDay: employeeId == null
            ? <int, double>{}
            : shiftsByEmployeeId[employeeId] ?? <int, double>{},
        paid: employeeId == null ? 0.0 : paidByEmployeeId[employeeId] ?? 0.0,
      );
    }).toList();

    _monthlyTimesheetCache[cacheKey] = _MonthlyTimesheetCacheEntry(
      rows: _copyMonthlyRows(result),
      createdAt: DateTime.now(),
    );

    return _copyMonthlyRows(result);
  }

  static Future<MonthlyTimesheetRow> fetchMonthlyTimesheetForEmployee({
    required Employee employee,
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    final employeeId = employee.id;

    if (employeeId == null || employeeId.trim().isEmpty) {
      return MonthlyTimesheetRow(
        employee: employee,
        shiftsByDay: const <int, double>{},
        paid: 0.0,
      );
    }

    final cacheKey = _employeeMonthCacheKey(
      employeeId: employeeId,
      year: year,
      month: month,
    );
    final cached = _employeeMonthlyTimesheetCache[cacheKey];

    if (!forceRefresh &&
        cached != null &&
        _isFresh(cached.createdAt, _reportCacheTtl)) {
      return cached.row;
    }

    final firstDate = DateTime(year, month, 1);
    final lastDate = DateTime(year, month + 1, 0);

    final attendanceRows = await _client
        .from('attendance')
        .select('work_date, shifts')
        .eq('employee_id', employeeId)
        .gte('work_date', dateKey(firstDate))
        .lte('work_date', dateKey(lastDate));

    final shiftsByDay = <int, double>{};

    for (final row in attendanceRows) {
      final workDateText = row['work_date']?.toString();

      if (workDateText == null) continue;

      final workDate = DateTime.tryParse(workDateText);

      if (workDate == null) continue;

      shiftsByDay[workDate.day] = _toDouble(row['shifts']);
    }

    final paymentRows = await _client
        .from('payments')
        .select('amount')
        .eq('period_year', year)
        .eq('period_month', month)
        .eq('employee_id', employeeId);

    double paid = 0.0;

    for (final row in paymentRows) {
      paid += _toDouble(row['amount']);
    }

    final result = MonthlyTimesheetRow(
      employee: employee,
      shiftsByDay: shiftsByDay,
      paid: paid,
    );

    _employeeMonthlyTimesheetCache[cacheKey] =
        _EmployeeMonthlyTimesheetCacheEntry(
          row: result,
          createdAt: DateTime.now(),
        );

    return result;
  }

  static Future<List<PeriodTimesheetRow>> fetchPeriodTimesheet({
    required DateTime startDate,
    required DateTime endDate,
    String? objectName,
    bool includeFired = false,
    bool forceRefresh = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);
    final cacheKey = _periodCacheKey(
      startDate: startDate,
      endDate: endDate,
      objectName: cleanObject,
      includeFired: includeFired,
    );
    final cached = _periodTimesheetCache[cacheKey];

    if (!forceRefresh &&
        cached != null &&
        _isFresh(cached.createdAt, _reportCacheTtl)) {
      return _copyPeriodRows(cached.rows);
    }

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

    final result = employees.map((employee) {
      final employeeId = employee.id;

      return PeriodTimesheetRow(
        employee: employee,
        shiftsByDate: employeeId == null
            ? <String, double>{}
            : shiftsByEmployeeId[employeeId] ?? <String, double>{},
      );
    }).toList();

    _periodTimesheetCache[cacheKey] = _PeriodTimesheetCacheEntry(
      rows: _copyPeriodRows(result),
      createdAt: DateTime.now(),
    );

    return _copyPeriodRows(result);
  }
}

class _AttendanceTotals {
  double shifts = 0;
}

class _ShiftValuesCacheEntry {
  final Map<String, double> values;
  final DateTime createdAt;

  const _ShiftValuesCacheEntry({required this.values, required this.createdAt});
}

class _MonthlyTimesheetCacheEntry {
  final List<MonthlyTimesheetRow> rows;
  final DateTime createdAt;

  const _MonthlyTimesheetCacheEntry({
    required this.rows,
    required this.createdAt,
  });
}

class _EmployeeMonthlyTimesheetCacheEntry {
  final MonthlyTimesheetRow row;
  final DateTime createdAt;

  const _EmployeeMonthlyTimesheetCacheEntry({
    required this.row,
    required this.createdAt,
  });
}

class _PeriodTimesheetCacheEntry {
  final List<PeriodTimesheetRow> rows;
  final DateTime createdAt;

  const _PeriodTimesheetCacheEntry({
    required this.rows,
    required this.createdAt,
  });
}

class _AttendanceReportCacheEntry {
  final List<AttendanceReportRow> rows;
  final DateTime createdAt;

  const _AttendanceReportCacheEntry({
    required this.rows,
    required this.createdAt,
  });
}
