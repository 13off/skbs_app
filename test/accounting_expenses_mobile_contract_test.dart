import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('accountant uses compact mobile expenses workspace without losing tools', () {
    final main = source(
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    );
    final expenses = source(
      'lib/features/expenses/presentation/expenses_screen.dart',
    );

    expect(
      main,
      contains('2 => const ExpensesScreen(compactMobileHeader: true),'),
    );
    expect(expenses, contains('final bool compactMobileHeader;'));
    expect(expenses, contains('this.compactMobileHeader = false'));
    expect(
      expenses,
      contains('widget.compactMobileHeader && constraints.maxWidth < 700'),
    );
    expect(
      expenses,
      contains("ValueKey('accounting-expenses-compact-mobile')"),
    );
    expect(expenses, contains("label: const Text('Добавить')"));
    expect(expenses, contains('categoryFilter(compact: true)'));
    expect(expenses, contains('objectFilter(compact: true)'));
    expect(expenses, contains('onPressed: choosePeriod'));

    // Shared mechanics and the desktop presentation stay in the same workspace.
    expect(expenses, contains('Future<void> editExpense('));
    expect(expenses, contains('Future<void> editPayment('));
    expect(expenses, contains('Widget receiptStatus('));
    expect(expenses, contains('Widget desktopExpenseCard('));
    expect(expenses, contains('Widget mobileExpenseCard('));
  });
}
