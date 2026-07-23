import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260723200000_get_payment_rows_fast.sql';

  test('payment lists and receipts use one protected RPC', () {
    final source = File('lib/data/payment_repository.dart').readAsStringSync();
    final start = source.indexOf(
      'static Future<List<PaymentRecord>> _fetchPaymentsForEmployee',
    );
    final end = source.indexOf(
      'static Future<List<PaymentReceipt>> addReceiptsToPayment',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final loaders = source.substring(start, end);
    expect(loaders, contains("'get_payment_rows_fast'"));
    expect(loaders, contains("'p_employee_ids'"));
    expect(loaders, contains("row['receipts']"));
    expect(loaders, contains('PaymentReceipt.fromMap'));
    expect(loaders, isNot(contains(".from('payments')")));
    expect(loaders, isNot(contains('fetchReceiptsForPaymentIds')));
  });

  test('payment RPC keeps RLS and current-company boundaries', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('security invoker'));
    expect(sql, isNot(contains('security definer')));
    expect(sql, contains('(select auth.uid()) is not null'));
    expect(sql, contains('current_user_company_id()'));
    expect(sql, contains('payment.deleted_at is null'));
    expect(sql, contains('payment.employee_id = any(p_employee_ids)'));
    expect(sql, contains('public.payment_receipts'));
  });

  test('payment RPC aggregates receipts once and is authenticated only', () {
    final sql = File(migrationPath).readAsStringSync();

    expect(sql, contains('visible_payments as materialized'));
    expect(sql, contains('grouped_receipts as materialized'));
    expect(sql, contains('jsonb_agg'));
    expect(sql, contains("'[]'::jsonb"));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
  });
}
