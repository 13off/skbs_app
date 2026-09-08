import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume UI date picker cannot choose future dates', () {
    final source = File(
      'lib/features/estimator/presentation/estimator_manual_volumes_screen.dart',
    ).readAsStringSync();

    expect(source, contains('lastDate: DateTime.now()'));
  });
}
