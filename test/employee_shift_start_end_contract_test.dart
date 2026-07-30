import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('смена начинается и заканчивается только с координатой', () {
    final repository = File(
      'lib/features/employee/data/employee_work_action_repository.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/employee-work-actions/index.ts',
    ).readAsStringSync();

    expect(repository, contains('required EmployeeLocationPoint point'));
    expect(repository, contains("'start_shift'"));
    expect(repository, contains("'finish_shift'"));
    expect(edge, contains('coordinateFrom(input)'));
    expect(edge, contains('savePoint('));
    expect(edge, contains('point, "finish"'));
    expect(edge, contains('"start",'));
    expect(edge, contains('ended_at: point.recordedAt'));
  });
}
