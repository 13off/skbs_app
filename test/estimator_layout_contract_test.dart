import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimator workspace does not nest a ListView inside AppPage', () {
    final source = File(
      'lib/features/estimator/presentation/estimator_main_screen.dart',
    ).readAsStringSync();

    final workScreenStart = source.indexOf('class _EstimatorWorkScreenState');
    final factStart = source.indexOf('class _Fact');
    expect(workScreenStart, greaterThanOrEqualTo(0));
    expect(factStart, greaterThan(workScreenStart));

    final workScreenSource = source.substring(workScreenStart, factStart);
    expect(workScreenSource, contains('return AppPage('));
    expect(workScreenSource, contains('onRefresh: refresh'));
    expect(workScreenSource, isNot(contains('child: ListView(')));
    expect(workScreenSource, isNot(contains('return RefreshIndicator(')));
  });
}
