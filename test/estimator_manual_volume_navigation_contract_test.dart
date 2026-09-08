import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimator navigation exposes volume, closing and package workspaces', () {
    final source = File(
      'lib/features/estimator/presentation/estimator_main_screen.dart',
    ).readAsStringSync();

    expect(source, contains('PersistentTabController(pageCount: 6)'));
    expect(source, contains('EstimatorManualVolumesScreen'));
    expect(source, contains("label: 'Ручные'"));
    expect(source, contains('EstimatorClosingsScreen'));
    expect(source, contains("label: 'Закрытие'"));
    expect(source, contains('EstimatorClosingOperationsIndexScreen'));
    expect(source, contains("label: 'Пакет'"));
  });
}
