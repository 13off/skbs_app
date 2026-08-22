import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_data_sync.dart';
import 'attendance_repository.dart';
import 'payment_receipt_repository.dart';

class PaymentRepository {
  static final _client = Supabase.instance.client;

  static const Duration _employeePaymentsCacheTtl = Duration(seconds: 30);
  static const Duration _bulkPaymentsCacheTtl = Duration(seconds: 20);
  static const Duration _paymentTotalsCacheTtl = Duration(seconds: 20);

  static final Map<String, _EmployeePaymentsCacheEntry> _employeePaymentsCache =
      {};
  static final Map<String, _BulkPaymentsCacheEntry> _bulkPaymentsCache = {};
  static final Map<String, Future<List<PaymentRecord>>>
  _employeePaymentRequests = {};
  static final Map<String, Future<List<PaymentRecord>>> _bulkPaymentRequests =
      {};
  static final Map<String, _PaymentTotalsCacheEntry> _paymentTotalsCache = {};
  static final Map<String, Future<Map<String, double>>> _paymentTotalsRequests =
      {};
  static int _cacheGeneration = 0;

  static String dateKey(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    final month = cleanDate.month.toString().padLeft(2, '0');
    final day = cleanDate.day.toString().padLeft(2, '0');

    return '${cleanDate.year}-$month-$day';
  }

  static void clearCache() {
    _cacheGeneration++;
    _employeePaymentsCache.clear();
    _bulkPaymentsCache.clear();
    _employeePaymentRequests.clear();
    _bulkPaymentRequests.clear();
    _paymentTotalsCache.clear();
    _paymentTotalsRequests.clear();
  }

  static void clearEmployeePaymentsCache(String employeeId) {
    final cleanEmployeeId = employeeId.trim();

    if (cleanEmployeeId.isEmpty) return;

    _cacheGeneration++;
    _employeePaymentsCache.remove(cleanEmployeeId);
    _bulkPaymentsCache.clear();
    _employeePaymentRequests.remove(cleanEmployeeId);
    _bulkPaymentRequests.clear();
    _paymentTotalsCache.clear();
    _paymentTotalsRequests.clear();
  }

  static bool _isEmployeePaymentsCacheFresh(_EmployeePaymentsCacheEntry entry) {
    return DateTime.now().difference(entry.createdAt) <
        _employeePaymentsCacheTtl;
  }

  static bool _isBulkPaymentsCacheFresh(_BulkPaymentsCacheEntry entry) {
    return DateTime.now().difference(entry.createdAt) < _bulkPaymentsCacheTtl;
  }

  static List<PaymentRecord> _copyPayments(List<PaymentRecord> payments) {
    return List<PaymentRecord>.from(payments);
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();

    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  static Future<String?> addPayment({
    required String employeeId,
    required int periodYear,
    required int periodMonth,
    required DateTime paymentDate,
    required double amount,
    required String paymentType,
    required String comment,
    List<PickedPaymentReceiptFile> receiptFiles = const [],
  }) async {
    final row = await _client
        .from('payments')
        .insert({
          'employee_id': employeeId,
          'period_year': periodYear,
          'period_month': periodMonth,
          'payment_date': dateKey(paymentDate),
          'amount': amount,
          'payment_type': paymentType,
          'comment': comment,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    final paymentId = row['id']?.toString();

    if (paymentId != null && paymentId.isNotEmpty && receiptFiles.isNotEmpty) {
      try {
        await PaymentReceiptRepository.uploadReceiptFiles(
          paymentId: paymentId,
          employeeId: employeeId,
          files: receiptFiles,
        );
      } catch (_) {
        // Не оставляем «успешную» выплату без выбранного пользователем чека.
        // Иначе повторное нажатие после ошибки создаёт дубликаты выплат.
        try {
          await _client.from('payments').delete().eq('id', paymentId);
        } catch (_) {
          // Исходная ошибка загрузки важнее ошибки компенсационной очистки.
        }
        clearEmployeePaymentsCache(employeeId);
        AttendanceRepository.clearCache();
        rethrow;
      }
    }

    clearEmployeePaymentsCache(employeeId);
    AttendanceRepository.clearCache();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.payments},
      context: <String, dynamic>{
        'table': 'payments',
        'employee_id': employeeId,
        'period_year': periodYear,
        'period_month': periodMonth,
      },
    );

    return paymentId;
  }

  static Future<List<PaymentRecord>> fetchPaymentsForEmployee(
    String employeeId, {
    bool forceRefresh = false,
  }) async {
    final key = employeeId.trim();
    final running = _employeePaymentRequests[key];
    if (running != null) return _copyPayments(await running);
    final request = _fetchPaymentsForEmployee(
      employeeId,
      forceRefresh: forceRefresh,
    );
    _employeePaymentRequests[key] = request;
    try {
      return _copyPayments(await request);
    } finally {
      if (identical(_employeePaymentRequests[key], request)) {
        _employeePaymentRequests.remove(key);
      }
    }
  }

  static Future<List<PaymentRecord>> _fetchPaymentsForEmployee(
    String employeeId, {
    bool forceRefresh = false,
  }) async {
    final generation = _cacheGeneration;
    final cleanEmployeeId = employeeId.trim();

    if (cleanEmployeeId.isEmpty) return <PaymentRecord>[];

    final cached = _employeePaymentsCache[cleanEmployeeId];

    if (!forceRefresh &&
        cached != null &&
        _isEmployeePaymentsCacheFresh(cached)) {
      return _copyPayments(cached.payments);
    }

    final payments = await _fetchPaymentRows(<String>[cleanEmployeeId]);

    if (generation == _cacheGeneration) {
      _employeePaymentsCache[cleanEmployeeId] = _EmployeePaymentsCacheEntry(
        payments: _copyPayments(payments),
        createdAt: DateTime.now(),
      );
    }

    return _copyPayments(payments);
  }

  static Future<List<PaymentRecord>> fetchPaymentsForEmployees(
    List<String> employeeIds, {
    bool forceRefresh = false,
  }) async {
    final cleanIds =
        employeeIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final key = cleanIds.join('|');
    final running = _bulkPaymentRequests[key];
    if (running != null) return _copyPayments(await running);
    final request = _fetchPaymentsForEmployees(
      cleanIds,
      cacheKey: key,
      forceRefresh: forceRefresh,
    );
    _bulkPaymentRequests[key] = request;
    try {
      return _copyPayments(await request);
    } finally {
      if (identical(_bulkPaymentRequests[key], request)) {
        _bulkPaymentRequests.remove(key);
      }
    }
  }

  static Future<List<PaymentRecord>> _fetchPaymentsForEmployees(
    List<String> employeeIds, {
    required String cacheKey,
    bool forceRefresh = false,
  }) async {
    final generation = _cacheGeneration;
    final cleanIds = employeeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (cleanIds.isEmpty) return <PaymentRecord>[];

    if (cleanIds.length == 1) {
      return fetchPaymentsForEmployee(
        cleanIds.first,
        forceRefresh: forceRefresh,
      );
    }

    final cached = _bulkPaymentsCache[cacheKey];
    if (!forceRefresh && cached != null && _isBulkPaymentsCacheFresh(cached)) {
      return _copyPayments(cached.payments);
    }

    final payments = await _fetchPaymentRows(cleanIds);
    final createdAt = DateTime.now();

    if (generation == _cacheGeneration) {
      _bulkPaymentsCache[cacheKey] = _BulkPaymentsCacheEntry(
        payments: _copyPayments(payments),
        createdAt: createdAt,
      );
      _warmEmployeePaymentCaches(
        employeeIds: cleanIds,
        payments: payments,
        createdAt: createdAt,
      );
    }

    return _copyPayments(payments);
  }

  static void _warmEmployeePaymentCaches({
    required List<String> employeeIds,
    required List<PaymentRecord> payments,
    required DateTime createdAt,
  }) {
    final groupedPayments = <String, List<PaymentRecord>>{
      for (final employeeId in employeeIds) employeeId: <PaymentRecord>[],
    };

    for (final payment in payments) {
      final employeeId = payment.employeeId.trim();
      groupedPayments[employeeId]?.add(payment);
    }

    for (final entry in groupedPayments.entries) {
      _employeePaymentsCache[entry.key] = _EmployeePaymentsCacheEntry(
        payments: _copyPayments(entry.value),
        createdAt: createdAt,
      );
    }
  }

  static Future<List<PaymentRecord>> _fetchPaymentRows(
    List<String> employeeIds,
  ) async {
    final response = await _client.rpc<dynamic>(
      'get_payment_rows_fast',
      params: <String, dynamic>{'p_employee_ids': employeeIds},
    );
    if (response is! List) return <PaymentRecord>[];

    return response
        .whereType<Map>()
        .map<PaymentRecord>((rawRow) {
          final row = Map<String, dynamic>.from(rawRow);
          final receiptRows = row['receipts'];
          final receipts = receiptRows is List
              ? receiptRows
                    .whereType<Map>()
                    .map(
                      (receipt) => PaymentReceipt.fromMap(
                        Map<String, dynamic>.from(receipt),
                      ),
                    )
                    .toList(growable: false)
              : <PaymentReceipt>[];

          return PaymentRecord.fromMap(row, receipts: receipts);
        })
        .toList(growable: false);
  }

  static String _paymentTotalsKey({
    required List<String> employeeIds,
    required int periodYear,
    required int periodMonth,
    required DateTime startDate,
    required DateTime endDate,
    required bool byPaymentDate,
  }) {
    return '${employeeIds.join('|')}::$periodYear::$periodMonth::'
        '${dateKey(startDate)}::${dateKey(endDate)}::$byPaymentDate';
  }

  static Future<Map<String, double>> fetchPaymentTotalsForEmployees(
    List<String> employeeIds, {
    required int periodYear,
    required int periodMonth,
    required DateTime startDate,
    required DateTime endDate,
    required bool byPaymentDate,
    bool forceRefresh = false,
  }) async {
    final cleanIds =
        employeeIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (cleanIds.isEmpty) return <String, double>{};

    final key = _paymentTotalsKey(
      employeeIds: cleanIds,
      periodYear: periodYear,
      periodMonth: periodMonth,
      startDate: startDate,
      endDate: endDate,
      byPaymentDate: byPaymentDate,
    );
    final cached = _paymentTotalsCache[key];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _paymentTotalsCacheTtl) {
      return Map<String, double>.from(cached.totals);
    }

    final running = _paymentTotalsRequests[key];
    if (running != null) return Map<String, double>.from(await running);

    final generation = _cacheGeneration;
    late final Future<Map<String, double>> request;
    request =
        _loadPaymentTotals(
              employeeIds: cleanIds,
              periodYear: periodYear,
              periodMonth: periodMonth,
              startDate: startDate,
              endDate: endDate,
              byPaymentDate: byPaymentDate,
            )
            .then((totals) {
              if (generation == _cacheGeneration) {
                _paymentTotalsCache[key] = _PaymentTotalsCacheEntry(
                  totals: Map<String, double>.from(totals),
                  createdAt: DateTime.now(),
                );
              }
              return totals;
            })
            .whenComplete(() {
              if (identical(_paymentTotalsRequests[key], request)) {
                _paymentTotalsRequests.remove(key);
              }
            });
    _paymentTotalsRequests[key] = request;
    return Map<String, double>.from(await request);
  }

  static Future<Map<String, double>> _loadPaymentTotals({
    required List<String> employeeIds,
    required int periodYear,
    required int periodMonth,
    required DateTime startDate,
    required DateTime endDate,
    required bool byPaymentDate,
  }) async {
    final response = await _client.rpc<dynamic>(
      'get_payment_totals_fast',
      params: <String, dynamic>{
        'p_employee_ids': employeeIds,
        'p_period_year': periodYear,
        'p_period_month': periodMonth,
        'p_start_date': dateKey(startDate),
        'p_end_date': dateKey(endDate),
        'p_by_payment_date': byPaymentDate,
      },
    );
    if (response is! List) return <String, double>{};
    final totals = <String, double>{};
    for (final raw in response.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final employeeId = row['employee_id']?.toString().trim() ?? '';
      if (employeeId.isEmpty) continue;
      totals[employeeId] = _toDouble(row['paid']);
    }
    return totals;
  }

  static Future<List<PaymentReceipt>> addReceiptsToPayment({
    required String paymentId,
    required String employeeId,
    required List<PickedPaymentReceiptFile> receiptFiles,
  }) async {
    final uploadedReceipts = await PaymentReceiptRepository.uploadReceiptFiles(
      paymentId: paymentId,
      employeeId: employeeId,
      files: receiptFiles,
    );

    clearEmployeePaymentsCache(employeeId);
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.payments},
      context: <String, dynamic>{
        'table': 'payment_receipts',
        'employee_id': employeeId,
      },
    );

    return uploadedReceipts;
  }

  static Future<void> deletePayment(
    String paymentId, {
    String? employeeId,
  }) async {
    await PaymentReceiptRepository.deleteReceiptsForPayment(paymentId);

    await _client.from('payments').delete().eq('id', paymentId);

    final cleanEmployeeId = employeeId?.trim();

    if (cleanEmployeeId != null && cleanEmployeeId.isNotEmpty) {
      clearEmployeePaymentsCache(cleanEmployeeId);
    } else {
      clearCache();
    }

    AttendanceRepository.clearCache();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.payments},
      context: <String, dynamic>{
        'table': 'payments',
        'employee_id': cleanEmployeeId,
      },
    );
  }
}

class PaymentRecord {
  final String id;
  final String employeeId;
  final int periodYear;
  final int periodMonth;
  final DateTime paymentDate;
  final double amount;
  final String paymentType;
  final String comment;
  final DateTime updatedAt;
  final List<PaymentReceipt> receipts;

  const PaymentRecord({
    required this.id,
    required this.employeeId,
    required this.periodYear,
    required this.periodMonth,
    required this.paymentDate,
    required this.amount,
    required this.paymentType,
    required this.comment,
    required this.updatedAt,
    this.receipts = const [],
  });

  factory PaymentRecord.fromMap(
    Map<String, dynamic> map, {
    List<PaymentReceipt> receipts = const [],
  }) {
    return PaymentRecord(
      id: map['id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      periodYear: PaymentRepository._toInt(map['period_year']),
      periodMonth: PaymentRepository._toInt(map['period_month']),
      paymentDate: PaymentRepository._toDate(map['payment_date']),
      amount: PaymentRepository._toDouble(map['amount']),
      paymentType: map['payment_type']?.toString() ?? 'other',
      comment: map['comment']?.toString() ?? '',
      updatedAt: PaymentRepository._toDate(map['updated_at']),
      receipts: receipts,
    );
  }

  PaymentRecord copyWith({List<PaymentReceipt>? receipts}) {
    return PaymentRecord(
      id: id,
      employeeId: employeeId,
      periodYear: periodYear,
      periodMonth: periodMonth,
      paymentDate: paymentDate,
      amount: amount,
      paymentType: paymentType,
      comment: comment,
      updatedAt: updatedAt,
      receipts: receipts ?? this.receipts,
    );
  }
}

class _EmployeePaymentsCacheEntry {
  final List<PaymentRecord> payments;
  final DateTime createdAt;

  const _EmployeePaymentsCacheEntry({
    required this.payments,
    required this.createdAt,
  });
}

class _BulkPaymentsCacheEntry {
  final List<PaymentRecord> payments;
  final DateTime createdAt;

  const _BulkPaymentsCacheEntry({
    required this.payments,
    required this.createdAt,
  });
}

class _PaymentTotalsCacheEntry {
  final Map<String, double> totals;
  final DateTime createdAt;

  const _PaymentTotalsCacheEntry({
    required this.totals,
    required this.createdAt,
  });
}
