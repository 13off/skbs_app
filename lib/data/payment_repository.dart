import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_data_sync.dart';
import 'attendance_repository.dart';
import 'payment_receipt_repository.dart';

class PaymentRepository {
  static final _client = Supabase.instance.client;

  static const Duration _employeePaymentsCacheTtl = Duration(seconds: 30);

  static final Map<String, _EmployeePaymentsCacheEntry> _employeePaymentsCache =
      {};
  static final Map<String, Future<List<PaymentRecord>>>
  _employeePaymentRequests = {};
  static final Map<String, Future<List<PaymentRecord>>> _bulkPaymentRequests =
      {};

  static String dateKey(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    final month = cleanDate.month.toString().padLeft(2, '0');
    final day = cleanDate.day.toString().padLeft(2, '0');

    return '${cleanDate.year}-$month-$day';
  }

  static void clearCache() {
    _employeePaymentsCache.clear();
    _employeePaymentRequests.clear();
    _bulkPaymentRequests.clear();
  }

  static void clearEmployeePaymentsCache(String employeeId) {
    final cleanEmployeeId = employeeId.trim();

    if (cleanEmployeeId.isEmpty) return;

    _employeePaymentsCache.remove(cleanEmployeeId);
    _employeePaymentRequests.remove(cleanEmployeeId);
    _bulkPaymentRequests.clear();
  }

  static bool _isEmployeePaymentsCacheFresh(_EmployeePaymentsCacheEntry entry) {
    return DateTime.now().difference(entry.createdAt) <
        _employeePaymentsCacheTtl;
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
      await PaymentReceiptRepository.uploadReceiptFiles(
        paymentId: paymentId,
        employeeId: employeeId,
        files: receiptFiles,
      );
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
    if (!forceRefresh) {
      final running = _employeePaymentRequests[key];
      if (running != null) return _copyPayments(await running);
    }
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
    final cleanEmployeeId = employeeId.trim();

    if (cleanEmployeeId.isEmpty) return <PaymentRecord>[];

    final cached = _employeePaymentsCache[cleanEmployeeId];

    if (!forceRefresh &&
        cached != null &&
        _isEmployeePaymentsCacheFresh(cached)) {
      return _copyPayments(cached.payments);
    }

    final rows = await _client
        .from('payments')
        .select(
          'id, employee_id, period_year, period_month, payment_date, amount, payment_type, comment, updated_at',
        )
        .eq('employee_id', cleanEmployeeId)
        .order('payment_date', ascending: false)
        .order('updated_at', ascending: false);

    final payments = rows.map<PaymentRecord>((row) {
      return PaymentRecord.fromMap(row);
    }).toList();

    final receiptsByPaymentId =
        await PaymentReceiptRepository.fetchReceiptsForPaymentIds(
          payments.map((payment) => payment.id).toList(),
        );

    final paymentsWithReceipts = payments.map((payment) {
      return payment.copyWith(
        receipts: receiptsByPaymentId[payment.id] ?? <PaymentReceipt>[],
      );
    }).toList();

    _employeePaymentsCache[cleanEmployeeId] = _EmployeePaymentsCacheEntry(
      payments: _copyPayments(paymentsWithReceipts),
      createdAt: DateTime.now(),
    );

    return _copyPayments(paymentsWithReceipts);
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
    if (!forceRefresh) {
      final running = _bulkPaymentRequests[key];
      if (running != null) return _copyPayments(await running);
    }
    final request = _fetchPaymentsForEmployees(
      cleanIds,
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
    bool forceRefresh = false,
  }) async {
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

    final rows = await _client
        .from('payments')
        .select(
          'id, employee_id, period_year, period_month, payment_date, amount, payment_type, comment, updated_at',
        )
        .inFilter('employee_id', cleanIds)
        .order('payment_date', ascending: false)
        .order('updated_at', ascending: false);

    final payments = rows.map<PaymentRecord>((row) {
      return PaymentRecord.fromMap(row);
    }).toList();

    final receiptsByPaymentId =
        await PaymentReceiptRepository.fetchReceiptsForPaymentIds(
          payments.map((payment) => payment.id).toList(),
        );

    return payments.map((payment) {
      return payment.copyWith(
        receipts: receiptsByPaymentId[payment.id] ?? <PaymentReceipt>[],
      );
    }).toList();
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
