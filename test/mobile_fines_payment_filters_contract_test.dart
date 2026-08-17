import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile employees expose fines between payments and summary', () {
    final screen = File('lib/screens/employees_screen.dart').readAsStringSync();
    final actions = File(
      'lib/screens/employees/employees_actions.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/employees/employees_sections.dart',
    ).readAsStringSync();

    expect(screen, contains("import 'absence_fines_screen.dart';"));
    expect(actions, contains('void openFines()'));
    expect(actions, contains('const AbsenceFinesScreen()'));

    final payments = sections.indexOf("label: 'Выплаты'");
    final fines = sections.indexOf("label: 'Штрафы'");
    final summary = sections.indexOf("label: 'Сводка'");
    final add = sections.indexOf("label: 'Добавить'");
    expect(payments, greaterThanOrEqualTo(0));
    expect(fines, greaterThan(payments));
    expect(summary, greaterThan(fines));
    expect(add, greaterThan(summary));
    expect(sections, contains('onTap: openFines'));
  });

  test('mobile employee actions use balanced two-row layout', () {
    final sections = File(
      'lib/screens/employees/employees_sections.dart',
    ).readAsStringSync();

    expect(sections, contains('Widget actionCell'));
    expect(sections, contains('return Expanded('));
    expect(sections, contains('mainAxisAlignment: MainAxisAlignment.center'));
  });

  test('payments keep fines out of overlays and use full-width work cards', () {
    final payments = File('lib/screens/payments_screen.dart').readAsStringSync();
    final feature = File(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    ).readAsStringSync();
    final premium = File('lib/widgets/premium_ui_v2.dart').readAsStringSync();

    expect(payments, contains('chipTheme'));
    expect(payments, contains('StadiumBorder'));
    expect(feature, contains("'Режим учёта'"));
    expect(feature, contains("'За расчётный период'"));
    expect(feature, contains("'По дате выплаты'"));
    expect(feature, contains("'Работающие'"));
    expect(feature, contains("'Уволенные'"));
    expect(premium, contains('constraints.hasBoundedWidth'));
    expect(premium, contains('SizedBox(width: double.infinity'));

    expect(payments, isNot(contains('PendingAbsenceFinesCard')));
    expect(payments, isNot(contains('Positioned(')));
    expect(payments, isNot(contains('Stack(')));
  });
}
