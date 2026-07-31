import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('кабинет и все действия используют один явный employee_id', () {
    final cabinet = File(
      'lib/features/employee/data/employee_task_cabinet_repository.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/employee/data/employee_shift_action_repository.dart',
    ).readAsStringSync();
    final runtime = File(
      'lib/features/employee/data/employee_shift_runtime.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/employee-shift-actions/index.ts',
    ).readAsStringSync();

    expect(cabinet, contains("'employee_id': requestedEmployeeId"));
    expect(cabinet, contains('result.profile.employeeId != requestedEmployeeId'));
    expect(actions, contains("'employee_id': cleanEmployeeId"));
    expect(actions, contains("'employee-shift-actions'"));
    expect(runtime, contains('EmployeeShiftActionRepository.startShift('));
    expect(runtime, contains('employeeId: cleanEmployeeId'));
    expect(edge, contains('requestedEmployeeId'));
    expect(edge, contains('resolveEmployee(admin, viewer, requestedEmployeeId)'));
    expect(edge, isNot(contains('set_object_geofence')));
    expect(edge, isNot(contains('start_distance_m: distance')));
  });
}
