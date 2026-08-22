import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('payment keeps settlement period separate from actual date', () {
    final add = source('lib/screens/add_payment_screen.dart');
    final repository = source('lib/data/payment_repository.dart');
    final history = source('lib/screens/payment_history_screen.dart');

    expect(add, contains('late DateTime settlementMonth'));
    expect(add, contains("label: Text('За период: \$settlementPeriodTitle')"));
    expect(add, contains('periodYear: settlementMonth.year'));
    expect(add, contains('periodMonth: settlementMonth.month'));
    expect(repository, contains("'period_year': periodYear"));
    expect(repository, contains("'period_month': periodMonth"));
    expect(repository, contains("'payment_date': dateKey(paymentDate)"));
    expect(
      history,
      contains("'Выплачено: \${formatDate(payment.paymentDate)}'"),
    );
    expect(history, contains("'За период: \${periodTitle(payment)}'"));
  });

  test('existing payment types remain unchanged', () {
    final add = source('lib/screens/add_payment_screen.dart');
    expect(add, contains("'advance': 'Аванс'"));
    expect(add, contains("'salary': 'Заработная плата'"));
    expect(add, contains("'fine': 'Штраф'"));
  });

  test('payments screen supports settlement and cash-date modes', () {
    final screen = source(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    );
    final repository = source('lib/data/payment_repository.dart');

    expect(screen, contains('_PaymentAccountingMode.settlementPeriod'));
    expect(screen, contains('_PaymentAccountingMode.paymentDate'));
    expect(screen, contains('fetchPaymentTotalsForEmployees'));
    expect(screen, contains('periodYear: targetMonth.year'));
    expect(screen, contains('periodMonth: targetMonth.month'));
    expect(screen, contains('byPaymentDate: mode == _PaymentAccountingMode.paymentDate'));
    expect(repository, contains("'p_period_year': periodYear"));
    expect(repository, contains("'p_period_month': periodMonth"));
    expect(repository, contains("'p_by_payment_date': byPaymentDate"));
    expect(screen, contains("label: const Text('За расчётный период')"));
    expect(screen, contains("label: const Text('По дате выплаты')"));
    expect(screen, contains("title: 'Фактически выплачено'"));
    expect(screen, contains('mode == _PaymentAccountingMode.settlementPeriod'));
  });
}
