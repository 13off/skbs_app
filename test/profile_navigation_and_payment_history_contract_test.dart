import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('профиль использует только верхнюю шестерёнку без стрелки назад', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final appPage = File('lib/widgets/app_page.dart').readAsStringSync();

    expect(profile, contains("tooltip: 'Настройки'"));
    expect(profile, contains('suppressAutomaticBackButton: true'));
    expect(profile, isNot(contains("title: 'Настройки'")));
    expect(appPage, contains('final bool suppressAutomaticBackButton;'));
    expect(
      appPage,
      contains('!suppressAutomaticBackButton && (showBackButton || canPop)'),
    );
  });

  test(
    'из истории выплат можно открыть добавление для текущего сотрудника',
    () {
      final history = File(
        'lib/screens/payment_history_screen.dart',
      ).readAsStringSync();

      expect(history, contains("import 'add_payment_screen.dart';"));
      expect(history, contains('AddPaymentScreen('));
      expect(history, contains('initialEmployeeId: employeeId'));
      expect(history, contains("label: const Text('Добавить выплату')"));
      expect(history, contains('await loadHistory(forceRefresh: true)'));
    },
  );
}
