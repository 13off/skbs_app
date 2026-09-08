import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimator navigation exposes manual volume journal', () {
    final source = File(
      'lib/features/estimator/presentation/estimator_main_screen.dart',
    ).readAsStringSync();

    expect(source, contains('PersistentTabController(pageCount: 4)'));
    expect(source, contains('EstimatorManualVolumesScreen'));
    expect(source, contains("label: 'Ручные'"));
  });
}
