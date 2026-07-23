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

  test('independent photo and receipt uploads run concurrently', () {
    final photos = source('lib/data/task_photo_repository.dart');
    final receipts = source('lib/data/payment_receipt_repository.dart');
    expect(photos, contains('await Future.wait('));
    expect(receipts, contains('await Future.wait('));
    expect(receipts, contains(".from('payment_receipts')"));
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
