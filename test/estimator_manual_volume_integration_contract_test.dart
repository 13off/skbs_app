import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only approved cumulative feed receives active manual rows', () {
    final source = File(
      'lib/features/estimator/data/task_completion_report_repository.dart',
    ).readAsStringSync();

    expect(source, contains("if (cleanStatus == 'approved')"));
    expect(source, contains('EstimatorManualVolumeRepository.fetchAll()'));
    expect(source, contains('if (manual.isVoided) continue;'));
    expect(source, contains("workLocation: 'Вручную'"));
    expect(source, contains("axes: 'Вручную · \${manual.reasonTitle}'"));
  });
}
