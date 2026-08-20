import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/timesheet/models/timesheet_group.dart';

void main() {
  test('timesheet group maps members and system flag', () {
    final group = TimesheetGroup.fromMap(<String, dynamic>{
      'id': 'group-1',
      'object_id': 'object-1',
      'object_name': 'Мурманск',
      'name': 'Общая',
      'sort_order': 1000000,
      'is_system': true,
      'employee_ids': <String>['employee-1', 'employee-2'],
    });

    expect(group.name, 'Общая');
    expect(group.isSystem, isTrue);
    expect(group.employeeIds, containsAll(<String>['employee-1', 'employee-2']));
    expect(group.containsEmployee('employee-1'), isTrue);
    expect(group.containsEmployee('employee-3'), isFalse);
  });

  test('timesheet UI has only real groups and no ungrouped filter', () {
    final mobile = File('lib/screens/timesheet/timesheet_sections.dart')
        .readAsStringSync();
    final mobileState = File('lib/screens/timesheet_screen.dart').readAsStringSync();
    final desktop = File('lib/screens/desktop_timesheet_screen.dart')
        .readAsStringSync();
    final manager = File('lib/screens/timesheet_group_manager_sheet.dart')
        .readAsStringSync();

    expect(mobile, contains("Text('Все группы')"));
    expect(mobile, isNot(contains("Text('Без группы')")));
    expect(mobileState, isNot(contains('_ungroupedTimesheetFilter')));
    expect(desktop, isNot(contains('ungroupedFilter')));
    expect(desktop, isNot(contains("Text('Без группы')")));
    expect(mobile, contains("tooltip: 'Управление группами'"));
    expect(mobile, contains('buildGroupHeader'));
    expect(desktop, contains('_TimesheetGroupTableHeader'));
    expect(manager, contains("'По умолчанию'"));
    expect(manager, contains('group.isSystem'));
    expect(manager, contains("'Создать группу'"));
  });

  test('database gives every active employee a default group', () {
    final migration = File(
      'supabase/migrations/20260820214500_timesheet_groups_always_assigned.sql',
    ).readAsStringSync();

    expect(migration, contains('add column if not exists is_system'));
    expect(migration, contains('ensure_timesheet_default_group'));
    expect(migration, contains("'Общая'"));
    expect(migration, contains('assign_employee_timesheet_group'));
    expect(migration, contains('objects_ensure_timesheet_default_group'));
    expect(migration, contains("raise exception 'Системную группу нельзя удалить'"));
    expect(migration, contains('is_system boolean'));
  });
}
