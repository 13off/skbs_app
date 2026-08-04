import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payments use a real desktop workspace', () {
    final source = File(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    ).readAsStringSync();

    expect(source, contains('constraints.maxWidth >= 1120'));
    expect(source, contains('BoxConstraints(maxWidth: double.infinity)'));
    expect(source, contains('width: 360'));
    expect(source, contains('buildDesktopPaymentsBody'));
    expect(source, contains('buildCompactPaymentsBody'));
  });

  test('payment report supports actual payment date ranges', () {
    final sheet = File(
      'lib/features/payments/presentation/widgets/payment_report_sheet.dart',
    ).readAsStringSync();
    final exporter = File(
      'lib/features/payments/data/payment_report_exporter.dart',
    ).readAsStringSync();

    expect(sheet, contains('По датам выплаты'));
    expect(sheet, contains('showDateRangePicker'));
    expect(sheet, contains('PaymentReportPeriodMode.paymentDateRange'));
    expect(exporter, contains(".gte('payment_date', _isoDate(from))"));
    expect(exporter, contains(".lte('payment_date', _isoDate(to))"));
    expect(exporter, contains('по_датам_'));
  });
}
