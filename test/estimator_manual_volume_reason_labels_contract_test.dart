import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume form exposes all supported reason choices', () {
    final source = File(
      'lib/features/estimator/presentation/estimator_manual_volumes_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Дополнительная работа'));
    expect(source, contains('Работа без задачи'));
    expect(source, contains('Корректировка объёма'));
    expect(source, contains('Перенос из другого периода'));
    expect(source, contains('Другое'));
  });
}
