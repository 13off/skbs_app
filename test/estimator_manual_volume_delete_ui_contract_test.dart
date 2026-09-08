import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume UI exposes annul instead of delete', () {
    final source = File(
      'lib/features/estimator/presentation/estimator_manual_volumes_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Аннулировать'));
    expect(source, isNot(contains('Удалить')));
  });
}
