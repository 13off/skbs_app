import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile expense card keeps a stable header and footer grid', () {
    final source = File(
      'lib/features/expenses/presentation/expenses_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Widget mobileExpenseCard(ExpenseItemData item)'));
    expect(source, contains("key: const ValueKey('expense-mobile-header')"));
    expect(source, contains("key: const ValueKey('expense-mobile-footer')"));
    expect(source, contains('crossAxisAlignment: CrossAxisAlignment.start'));
    expect(source, contains('textAlign: TextAlign.right'));
    expect(source, contains('receiptStatus(item)'));
    expect(source, contains('actionMenu(item)'));
  });
}
