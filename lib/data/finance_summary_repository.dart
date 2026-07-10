import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';
import 'employee_repository.dart';
import 'object_repository.dart';

class FinancePeriod {
  final int? year;
  final int? month;

  const FinancePeriod.month({required int year, required int month})
    : year = year,
      month = month;

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

  static const int _employeeChunkSize = 80;

  /// Одновременные одинаковые запросы используют один Future.
  ///
  /// Постоянный кэш здесь намеренно не хранится, чтобы после изменения табеля
  /// или выплаты главная всегда показывала свежую сумму.
  static final Map<String, Future<FinanceSummaryData>> _inFlight = {};

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

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  static String _requestKey({
    required FinancePeriod period,
    required String? objectName,
  }) {
    final periodPart = period.isAllTime
        ? 'all'
        : '${period.year}-${period.month}';
    final objectPart = _cleanObjectName(objectName) ?? '__all__';

    return '$periodPart::$objectPart';
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
  }) {
    final key = _requestKey(period: period, objectName: objectName);
    final running = _inFlight[key];

    if (running != null) return running;

    final future = _loadSummary(period: period, objectName: objectName);
    _inFlight[key] = future;

    future.whenComplete(() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    });

    return future;
  }

  static Future<FinanceSummaryData> _loadSummary({
    required FinancePeriod period,
    String? objectName,
  }) async {
    final cleanObject = _cleanObjectName(objectName);

    final initialResults = await Future.wait<dynamic>([
      EmployeeRepository.fetchEmployees(
        objectName: cleanObject,
        includeFired: true,
      ),
      if (cleanObject == null)
        ObjectRepository.fetchObjectNames()
      else
        Future<List<String>>.value(const <String>[]),
    ]);

    final allEmployees = initialResults[0] as List<Employee>;
    final activeObjectNames = cleanObject == null
        ? (initialResults[1] as List<String>).toSet()
        : null;

    final employees = activeObjectNames == null
        ? allEmployees
        : allEmployees
              .where(
                (employee) =>
                    activeObjectNames.contains(employee.objectName.trim()),
              )
              .toList();

    final employeesById = _employeesById(employees);

    if (employeesById.isEmpty) return FinanceSummaryData.empty;

    final employeeIds = employeesById.keys.toList();

    final dataResults = await Future.wait<List<dynamic>>([
      _fetchAttendanceRows(period: period, employeeIds: employeeIds),
      _fetchPaymentRows(period: period, employeeIds: employeeIds),
    ]);

    final attendanceRows = dataResults[0];
    final paymentRows = dataResults[1];

    double accrued = 0;
    double paid = 0;

    for (final row in attendanceRows) {
      final employeeId = row['employee_id']?.toString();
      final employee = employeeId == null ? null : employeesById[employeeId];

      if (employee == null) continue;

      accrued += _toDouble(row['shifts']) * employee.dailyRate;
    }

    for (final row in paymentRows) {
      final employeeId = row['employee_id']?.toString();

      if (employeeId == null || !employeesById.containsKey(employeeId)) {
        continue;
      }

      paid += _toDouble(row['amount']);
    }

    return FinanceSummaryData(accrued: accrued, paid: paid);
  }

  static Future<List<dynamic>> _fetchAttendanceRows({
    required FinancePeriod period,
    required List<String> employeeIds,
  }) async {
    final requests = <Future<List<dynamic>>>[];

    for (var start = 0; start < employeeIds.length; start += _employeeChunkSize) {
      final end = math.min(start + _employeeChunkSize, employeeIds.length);
      final chunk = employeeIds.sublist(start, end);

      requests.add(_fetchAttendanceChunk(period: period, employeeIds: chunk));
    }

    final chunks = await Future.wait<List<dynamic>>(requests);

    return chunks.expand((rows) => rows).toList();
  }

  static Future<List<dynamic>> _fetchAttendanceChunk({
    required FinancePeriod period,
    required List<String> employeeIds,
  }) async {
    if (period.isAllTime) {
      return await _client
          .from('attendance')
          .select('employee_id, shifts')
          .inFilter('employee_id', employeeIds);
    }

    final firstDate = _firstDateOfMonth(period);
    final lastDate = _lastDateOfMonth(period);

    return await _client
        .from('attendance')
        .select('employee_id, shifts')
        .inFilter('employee_id', employeeIds)
        .gte('work_date', _dateKey(firstDate))
        .lte('work_date', _dateKey(lastDate));
  }

  static Future<List<dynamic>> _fetchPaymentRows({
    required FinancePeriod period,
    required List<String> employeeIds,
  }) async {
    final requests = <Future<List<dynamic>>>[];

    for (var start = 0; start < employeeIds.length; start += _employeeChunkSize) {
      final end = math.min(start + _employeeChunkSize, employeeIds.length);
      final chunk = employeeIds.sublist(start, end);

      requests.add(_fetchPaymentChunk(period: period, employeeIds: chunk));
    }

    final chunks = await Future.wait<List<dynamic>>(requests);

    return chunks.expand((rows) => rows).toList();
  }

  static Future<List<dynamic>> _fetchPaymentChunk({
    required FinancePeriod period,
    required List<String> employeeIds,
  }) async {
    if (period.isAllTime) {
      return await _client
          .from('payments')
          .select('employee_id, amount')
          .inFilter('employee_id', employeeIds);
    }

    return await _client
        .from('payments')
        .select('employee_id, amount')
        .inFilter('employee_id', employeeIds)
        .eq('period_year', period.year!)
        .eq('period_month', period.month!);
  }
}
