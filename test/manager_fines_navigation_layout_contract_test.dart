import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manager desktop actions keep fines between payments and summary', () {
    final source = File('lib/screens/desktop_employees_view.dart').readAsStringSync();

    final payments = source.indexOf("const Text('Выплаты')");
    final fines = source.indexOf("const Text('Штрафы')");
    final summary = source.indexOf("const Text('Сводка')");
    final add = source.indexOf("const Text('Добавить')");

    expect(payments, greaterThanOrEqualTo(0));
    expect(fines, greaterThan(payments));
    expect(summary, greaterThan(fines));
    expect(add, greaterThan(summary));
    expect(source, contains('onOpenFines'));
  });

  test('fines open as a dedicated route instead of payments overlay', () {
    final adaptive = File(
      'lib/screens/adaptive_employees_screen.dart',
    ).readAsStringSync();
    final payments = File('lib/screens/payments_screen.dart').readAsStringSync();
    final fines = File('lib/screens/absence_fines_screen.dart').readAsStringSync();

    expect(adaptive, contains('AbsenceFinesScreen'));
    expect(adaptive, contains('onOpenFines: openFines'));
    expect(fines, contains('PendingAbsenceFinesCard'));

    expect(payments, isNot(contains('PendingAbsenceFinesCard')));
    expect(payments, isNot(contains('Positioned(')));
    expect(payments, isNot(contains('Stack(')));
  });
}
