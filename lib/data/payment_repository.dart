import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentRepository {
  static final _client = Supabase.instance.client;

  static String dateKey(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    final month = cleanDate.month.toString().padLeft(2, '0');
    final day = cleanDate.day.toString().padLeft(2, '0');

    return '${cleanDate.year}-$month-$day';
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

  static Future<void> addPayment({
    required String employeeId,
    required int periodYear,
    required int periodMonth,
    required DateTime paymentDate,
    required double amount,
    required String paymentType,
    required String comment,
  }) async {
    await _client.from('payments').insert({
      'employee_id': employeeId,
      'period_year': periodYear,
      'period_month': periodMonth,
      'payment_date': dateKey(paymentDate),
      'amount': amount,
      'payment_type': paymentType,
      'comment': comment,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<List<PaymentRecord>> fetchPaymentsForEmployee(
    String employeeId,
  ) async {
    final rows = await _client
        .from('payments')
        .select(
          'id, employee_id, period_year, period_month, payment_date, amount, payment_type, comment, updated_at',
        )
        .eq('employee_id', employeeId)
        .order('payment_date', ascending: false)
        .order('updated_at', ascending: false);

    return rows.map<PaymentRecord>((row) {
      return PaymentRecord.fromMap(row);
    }).toList();
  }

  static Future<void> deletePayment(String paymentId) async {
    await _client.from('payments').delete().eq('id', paymentId);
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
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
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
    );
  }
}
