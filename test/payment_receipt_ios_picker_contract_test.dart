import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment receipt picker declares iOS uniform type identifiers', () {
    final source = File(
      'lib/data/payment_receipt_repository.dart',
    ).readAsStringSync();

    expect(source, contains('uniformTypeIdentifiers'));
    expect(source, contains("'public.jpeg'"));
    expect(source, contains("'public.png'"));
    expect(source, contains("'org.webmproject.webp'"));
    expect(source, contains("'com.adobe.pdf'"));
    expect(source, contains('extensions: allowedExtensions'));
  });
}
