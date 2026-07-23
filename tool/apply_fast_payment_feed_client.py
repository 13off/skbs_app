from pathlib import Path
import re

path = Path('lib/data/payment_repository.dart')
text = path.read_text(encoding='utf-8')

employee_pattern = re.compile(
    r"  static Future<List<PaymentRecord>> _fetchPaymentsForEmployee\(.*?\n"
    r"  static Future<List<PaymentRecord>> fetchPaymentsForEmployees\(",
    re.DOTALL,
)

employee_replacement = """  static Future<List<PaymentRecord>> _fetchPaymentsForEmployee(
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

    final payments = await _fetchPaymentRows(<String>[cleanEmployeeId]);

    _employeePaymentsCache[cleanEmployeeId] = _EmployeePaymentsCacheEntry(
      payments: _copyPayments(payments),
      createdAt: DateTime.now(),
    );

    return _copyPayments(payments);
  }

  static Future<List<PaymentRecord>> fetchPaymentsForEmployees("""

text, employee_count = employee_pattern.subn(employee_replacement, text, count=1)
if employee_count != 1:
    raise SystemExit('single employee payment loader anchor not found')

bulk_pattern = re.compile(
    r"  static Future<List<PaymentRecord>> _fetchPaymentsForEmployees\(.*?\n"
    r"  static Future<List<PaymentReceipt>> addReceiptsToPayment\(",
    re.DOTALL,
)

bulk_replacement = """  static Future<List<PaymentRecord>> _fetchPaymentsForEmployees(
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

    return _fetchPaymentRows(cleanIds);
  }

  static Future<List<PaymentRecord>> _fetchPaymentRows(
    List<String> employeeIds,
  ) async {
    final response = await _client.rpc<dynamic>(
      'get_payment_rows_fast',
      params: <String, dynamic>{'p_employee_ids': employeeIds},
    );
    if (response is! List) return <PaymentRecord>[];

    return response.whereType<Map>().map<PaymentRecord>((rawRow) {
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
    }).toList(growable: false);
  }

  static Future<List<PaymentReceipt>> addReceiptsToPayment("""

text, bulk_count = bulk_pattern.subn(bulk_replacement, text, count=1)
if bulk_count != 1:
    raise SystemExit('bulk payment loader anchor not found')

path.write_text(text, encoding='utf-8')
