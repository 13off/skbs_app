import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const functionPath = 'supabase/functions/employee-cabinet/index.ts';

  test('режим руководителя открывает реальные данные сотрудника', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final function = File(functionPath).readAsStringSync();

    expect(wrapper, contains("actualRole: 'employee'"));
    expect(function, contains('const isManagerPreview'));
    expect(function, contains('.from("task_assignees")'));
    expect(function, contains('.order("created_at", { ascending: false })'));
    expect(function, contains('selectedEmployeeId'));
    expect(function, isNot(contains('.eq("role", "employee")')));
  });
}
