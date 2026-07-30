import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('смены защищены серверной проверкой компании и назначения', () {
    final edge = File(
      'supabase/functions/employee-work-actions/index.ts',
    ).readAsStringSync();

    expect(edge, contains('.eq("company_id", viewer.companyId)'));
    expect(edge, contains('assertAssignedTask'));
    expect(edge, contains('task_assignees'));
    expect(edge, contains('permissionScope !== "always"'));
    expect(edge, contains('coordinate.isMock'));
    expect(edge, contains('start_distance_m'));
  });
}
