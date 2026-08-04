import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/data/payment_repository.dart',
  ).readAsStringSync();

  group('PaymentRepository bulk cache contract', () {
    test('bulk responses have a short bounded cache', () {
      expect(source, contains('_bulkPaymentsCacheTtl'));
      expect(source, contains('_bulkPaymentsCache'));
      expect(source, contains('_isBulkPaymentsCacheFresh'));
    });

    test('bulk load warms individual employee payment caches', () {
      expect(source, contains('_warmEmployeePaymentCaches'));
      expect(source, contains('groupedPayments[employeeId]?.add(payment)'));
      expect(
        source,
        contains('_employeePaymentsCache[entry.key] ='),
      );
    });

    test('writes invalidate both individual and bulk payment caches', () {
      final clearMethod = RegExp(
        r'static void clearEmployeePaymentsCache\(String employeeId\) \{([\s\S]*?)\n  \}',
      ).firstMatch(source)?.group(1);

      expect(clearMethod, isNotNull);
      expect(clearMethod, contains('_employeePaymentsCache.remove'));
      expect(clearMethod, contains('_bulkPaymentsCache.clear()'));
      expect(clearMethod, contains('_bulkPaymentRequests.clear()'));
    });

    test('force refresh bypasses the reusable bulk result', () {
      expect(
        source,
        contains(
          'if (!forceRefresh && cached != null && '
          '_isBulkPaymentsCacheFresh(cached))',
        ),
      );
    });
  });
}
