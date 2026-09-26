import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('closed-period overpayments offer transfer to another period', () {
    final add = source('lib/screens/add_payment_screen.dart');

    expect(add, contains('selectedPeriodIsClosed'));
    expect(add, contains('Получается переплата'));
    expect(add, contains('Оставить переплату'));
    expect(add, contains('Перенести'));
    expect(add, contains('Куда перенести'));
    expect(add, contains('Осталось выплатить'));
    expect(add, contains('resolvePaymentAllocations'));
    expect(add, contains('selectedPaymentType == \'fine\''));
  });

  test('split payment persists several period allocations in one save', () {
    final repository = source('lib/data/payment_repository.dart');
    final add = source('lib/screens/add_payment_screen.dart');

    expect(repository, contains('class PaymentAllocationInput'));
    expect(repository, contains('addPaymentAllocations'));
    expect(repository, contains("'periods': cleanAllocations"));
    expect(add, contains('PaymentRepository.addPaymentAllocations'));
  });

  test('one physical receipt can stay linked to every split payment', () {
    final receipts = source('lib/data/payment_receipt_repository.dart');
    final repository = source('lib/data/payment_repository.dart');
    final migration = source(
      'supabase/migrations/20260926163000_payment_overpayment_period_split.sql',
    );

    expect(receipts, contains('linkExistingReceiptsToPayment'));
    expect(receipts, contains("select('id')"));
    expect(receipts, contains("eq('file_path', path)"));
    expect(repository, contains('sourceReceipts: primaryReceipts'));
    expect(
      migration,
      contains('drop constraint if exists payment_receipts_file_path_key'),
    );
    expect(
      migration,
      contains('payment_receipts_payment_file_path_uidx'),
    );
  });

  test('period balances are calculated server-side with current payroll rules', () {
    final repository = source('lib/data/payment_repository.dart');
    final migration = source(
      'supabase/migrations/20260926163000_payment_overpayment_period_split.sql',
    );

    expect(
      repository,
      contains("'get_employee_payment_period_balances'"),
    );
    expect(
      migration,
      contains('private.calculate_fixed_monthly_accrual'),
    );
    expect(migration, contains('sum(attendance_row.shifts)'));
    expect(migration, contains('sum(payment_row.amount)'));
  });
}
