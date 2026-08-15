import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/data/payment_receipt_repository.dart';

void main() {
  test('payment receipt storage key is ASCII even for Cyrillic file names', () {
    final storageName = PaymentReceiptRepository.safeStorageFileName(
      originalName: 'Изображение PNG.png',
      index: 1,
      extension: 'png',
    );

    expect(storageName, endsWith('.png'));
    expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(storageName), isTrue);
    expect(storageName, isNot(contains('Изображение')));
  });

  test('original payment receipt name is still stored for display', () {
    final originalName = 'Чек за проживание.pdf';
    final storageName = PaymentReceiptRepository.safeStorageFileName(
      originalName: originalName,
      index: 2,
      extension: 'pdf',
    );

    expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(storageName), isTrue);
    expect(storageName, isNot(contains(originalName)));
  });
}
