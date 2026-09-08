import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual volume screen does not nest a ListView inside AppPage', () {
    final source = File(
      'lib/features/estimator/presentation/estimator_manual_volumes_screen.dart',
    ).readAsStringSync();

    expect(source, contains('return AppPage('));
    expect(source, contains('onRefresh: refresh'));
    expect(source, isNot(contains('child: ListView(')));
    expect(source, isNot(contains('return RefreshIndicator(')));
  });
}
