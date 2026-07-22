import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Цветовой патч не должен менять выбор объекта, сотрудника и чеков.
  test('add payment uses adaptive period receipts and errors', () {
    final screen = File(
      'lib/screens/add_payment_screen.dart',
    ).readAsStringSync();

    expect(screen, contains("import '../app/app_adaptive_palette.dart';"));
    expect(screen, contains('AppAdaptivePalette.surfaceSoft'));
    expect(screen, contains('AppAdaptivePalette.surfaceElevated'));
    expect(screen, contains('AppAdaptivePalette.border'));
    expect(screen, contains('AppAdaptivePalette.textMuted'));
    expect(screen, contains('AppAdaptivePalette.danger'));

    expect(screen, contains('EmployeeRepository.fetchEmployees('));
    expect(screen, contains('ObjectRepository.fetchObjectNames()'));
    expect(screen, contains('PaymentRepository.addPayment('));
    expect(screen, contains('PaymentReceiptRepository.pickReceiptFiles()'));
    expect(screen, contains('employeeId: selectedEmployee.id!'));
    expect(screen, contains('paymentType: selectedPaymentType'));
    expect(screen, contains('receiptFiles: receiptFiles'));
    expect(screen, contains("title: const Text('Добавить выплату')"));
    expect(screen, contains("label: const Text('Повторить')"));
    expect(screen, contains("'Сохранить выплату'"));

    expect(screen, isNot(contains('color: Colors.grey.shade100')));
    expect(screen, isNot(contains('color: Colors.grey.shade700')));
    expect(screen, isNot(contains('color: Colors.white,')));
    expect(
      screen,
      isNot(contains('border: Border.all(color: Colors.grey.shade200)')),
    );
    expect(
      screen,
      isNot(contains('border: Border.all(color: Colors.grey.shade300)')),
    );
    expect(screen, isNot(contains('TextStyle(color: Colors.red)')));
  });
}
