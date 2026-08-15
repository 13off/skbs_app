import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('web image compression is asynchronous and avoids base64 copies', () {
    final image = source('lib/data/image_compression_service.dart');
    expect(image, contains("canvas.toBlob('image/jpeg'"));
    expect(image, contains('readAsArrayBuffer(blob)'));
    expect(image, isNot(contains('toDataUrl(')));
    expect(image, isNot(contains('base64Decode(')));
  });

  test('photo uploads stay concurrent while receipts prefer reliability', () {
    final photos = source('lib/data/task_photo_repository.dart');
    final receipts = source('lib/data/payment_receipt_repository.dart');

    expect(photos, contains('await Future.wait('));

    expect(receipts, contains('_uploadReceiptWithRetry'));
    expect(receipts, contains('_maxUploadAttempts = 3'));
    expect(receipts, contains('refreshSession()'));
    expect(receipts, contains('_uploadTimeout'));
    expect(receipts, contains('for (final item in uploadItems)'));
    expect(receipts, isNot(contains('uploadItems.map((item) async')));
    expect(receipts, contains(".from('payment_receipts')"));
  });

  test('partial uploads keep rollback cleanup', () {
    final photos = source('lib/data/task_photo_repository.dart');
    final receipts = source('lib/data/payment_receipt_repository.dart');
    expect(photos, contains('await removeStoragePaths(uploadedPaths)'));
    expect(receipts, contains(".from(bucketName).remove(uploadedPaths)"));
    expect(photos, contains('rethrow;'));
    expect(receipts, contains('rethrow;'));
  });

  test('new payment rolls back when its selected receipt cannot be saved', () {
    final payments = source('lib/data/payment_repository.dart');
    expect(payments, contains('PaymentReceiptRepository.uploadReceiptFiles'));
    expect(
      payments,
      contains("await _client.from('payments').delete().eq('id', paymentId)"),
    );
    expect(payments, contains('rethrow;'));
  });

  test('identical data requests share one in-flight future', () {
    final tasks = source('lib/data/task_repository.dart');
    final attendance = source('lib/data/attendance_repository.dart');
    final payments = source('lib/data/payment_repository.dart');
    expect(tasks, contains('_taskRequests'));
    expect(attendance, contains('_shiftValueRequests'));
    expect(attendance, contains('_monthlyTimesheetRequests'));
    expect(payments, contains('_employeePaymentRequests'));
    expect(payments, contains('_bulkPaymentRequests'));
  });
}
