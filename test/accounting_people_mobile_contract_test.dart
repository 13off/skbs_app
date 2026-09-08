import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('accountant mobile people workspace stays compact without losing actions', () {
    final sections = source('lib/screens/employees/employees_sections.dart');
    final view = source('lib/screens/employees/employees_view.dart');
    final adaptive = source('lib/screens/adaptive_employees_screen.dart');

    expect(
      sections,
      contains(
        'if (widget.profile.isAccountant) return accountantHeader(scopeTitle);',
      ),
    );
    expect(sections, contains('Widget accountantHeader(String scopeTitle)'));
    expect(sections, contains('Widget compactAccountantAction('));
    expect(sections, contains('SingleChildScrollView('));
    expect(sections, contains('scrollDirection: Axis.horizontal'));

    expect(sections, contains("label: 'Выплаты'"));
    expect(sections, contains('onTap: openPayments'));
    expect(sections, contains("label: 'Штрафы'"));
    expect(sections, contains('onTap: openFines'));
    expect(sections, contains("label: 'Сводка'"));
    expect(sections, contains('onTap: downloadSummary'));
    expect(sections, contains("label: 'Добавить'"));
    expect(sections, contains('onTap: addEmployee'));

    expect(view, contains('compactAccountantLayout = widget.profile.isAccountant'));
    expect(view, contains('compactAccountantLayout ? 10 : 14'));
    expect(view, contains('compactAccountantLayout ? 12 : 16'));
    expect(view, contains('compactAccountantLayout ? 10 : 18'));

    expect(adaptive, contains('EmployeeDetailsScreen(profile: widget.profile'));
    expect(adaptive, contains('PaymentsScreen('));
    expect(adaptive, contains('AbsenceFinesScreen'));
  });
}
