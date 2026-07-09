import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';
import 'attendance_repository.dart';
import 'employee_repository.dart';

class FinancePeriod {
  final int? year;
  final int? month;

  const FinancePeriod.month({required int this.year, required int this.month});

  const FinancePeriod.allTime() : year = null, month = null;

  bool get isAllTime => year == null || month == null;

  String title() {
    if (isAllTime) return 'за всё время';

    final monthName = _monthNames[month! - 1];

    return 'за $monthName $year';
  }

  String pickerTitle() {
    if (isAllTime) return 'За всё время';

    final monthName = _monthNamesCapitalized[month! - 1];

    return '$monthName $year';
  }

  static FinancePeriod current(DateTime date) {
    return FinancePeriod.month(year: date.year, month: date.month);
  }

  static List<FinancePeriod> recentMonths(DateTime from, {int count = 12}) {
    final periods = <FinancePeriod>[];

    for (var i = 0; i < count; i++) {
      final date = DateTime(from.year, from.month - i, 1);

      periods.add(FinancePeriod.month(year: date.year, month: date.month));
    }

    return periods;
  }

  static const List<String> _monthNames = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];

  static const List<String> _monthNamesCapitalized = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
}

class FinanceSummaryData {
  final double accrued;
  final double paid;

  const FinanceSummaryData({required this.accrued, required this.paid});

  static const empty = FinanceSummaryData(accrued: 0, paid: 0);

  double get balance => accrued - paid;

  double get paidProgress {
    if (accrued <= 0) return 0.0;

    return (paid / accrued).clamp(0.0, 1.0).toDouble();
  }
}

class FinanceSummaryRepository {
  static final _client = Supabase.instance.client;

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  static String? _cleanObjectName(String? objectName) {
    final clean = objectName?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  static DateTime _firstDateOfMonth(FinancePeriod period) {
    return DateTime(period.year!, period.month!, 1);
  }

  static DateTime _lastDateOfMonth(FinancePeriod period) {
    return DateTime(period.year!, period.month! + 1, 0);
  }

  static Map<String, Employee> _employeesById(List<Employee> employees) {
    final map = <String, Employee>{};

    for (final employee in employees) {
      final employeeId = employee.id?.trim();

      if (employeeId == null || employeeId.isEmpty) continue;

      map[employeeId] = employee;
    }

    return map;
  }

  static Future<FinanceSummaryData> fetchSummary({
    required FinancePeriod period,
    String? objectName,
  }) async {
    final cleanObject = _cleanObjectName(objectName);
    final employees = await EmployeeRepository.fetchEmployees(
      objectName: cleanObject,
      includeFired: true,
    );
    final employeesById = _employeesById(employees);

    if (employeesById.isEmpty) return FinanceSummaryData.empty;

    final employeeIds = employeesById.keys.toSet();

    final attendanceRows = await _fetchAttendanceRows(
      period: period,
      objectName: cleanObject,
    );
    final paymentRows = await _fetchPaymentRows(period: period);

    double accrued = 0;
    double paid = 0;

    for (final row in attendanceRows) {
      final employeeId = row['employee_id']?.toString();

      if (employeeId == null || !employeeIds.contains(employeeId)) continue;

      final employee = employeesById[employeeId];

      if (employee == null) continue;

      accrued += _toDouble(row['shifts']) * employee.dailyRate;
    }

    for (final row in paymentRows) {
      final employeeId = row['employee_id']?.toString();

      if (employeeId == null || !employeeIds.contains(employeeId)) continue;

      paid += _toDouble(row['amount']);
    }

    return FinanceSummaryData(accrued: accrued, paid: paid);
  }

  static Future<List<dynamic>> _fetchAttendanceRows({
    required FinancePeriod period,
    required String? objectName,
  }) async {
    if (period.isAllTime) {
      if (objectName == null) {
        return await _client.from('attendance').select('employee_id, shifts');
      }

      return await _client
          .from('attendance')
          .select('employee_id, shifts')
          .eq('object_name', objectName);
    }

    final firstDate = _firstDateOfMonth(period);
    final lastDate = _lastDateOfMonth(period);

    if (objectName == null) {
      return await _client
          .from('attendance')
          .select('employee_id, shifts')
          .gte('work_date', AttendanceRepository.dateKey(firstDate))
          .lte('work_date', AttendanceRepository.dateKey(lastDate));
    }

    return await _client
        .from('attendance')
        .select('employee_id, shifts')
        .gte('work_date', AttendanceRepository.dateKey(firstDate))
        .lte('work_date', AttendanceRepository.dateKey(lastDate))
        .eq('object_name', objectName);
  }

  static Future<List<dynamic>> _fetchPaymentRows({
    required FinancePeriod period,
  }) async {
    if (period.isAllTime) {
      return await _client.from('payments').select('employee_id, amount');
    }

    return await _client
        .from('payments')
        .select('employee_id, amount')
        .eq('period_year', period.year!)
        .eq('period_month', period.month!);
  }
}
