import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/timesheet/models/timesheet_group.dart';

void main() {
  test('timesheet group maps members and keeps one display label', () {
    final group = TimesheetGroup.fromMap(<String, dynamic>{
      'id': 'group-1',
      'object_id': 'object-1',
      'object_name': 'Мурманск',
      'name': 'Бетонщики',
      'sort_order': 10,
      'employee_ids': <String>['employee-1', 'employee-2'],
    });

    expect(group.name, 'Бетонщики');
    expect(group.employeeIds, containsAll(<String>['employee-1', 'employee-2']));
    expect(group.containsEmployee('employee-1'), isTrue);
    expect(group.containsEmployee('employee-3'), isFalse);
  });

  test('timesheet UI contains group filter, manager and section headers', () {
    final mobile = File('lib/screens/timesheet/timesheet_sections.dart')
        .readAsStringSync();
    final desktop = File('lib/screens/desktop_timesheet_screen.dart')
        .readAsStringSync();
    final manager = File('lib/screens/timesheet_group_manager_sheet.dart')
        .readAsStringSync();

    expect(mobile, contains("Text('Все группы')"));
    expect(mobile, contains("Text('Без группы')"));
    expect(mobile, contains("tooltip: 'Управление группами'"));
    expect(mobile, contains('buildGroupHeader'));
    expect(desktop, contains('groupFilter = allGroupsFilter'));
    expect(desktop, contains("child: Text('Все группы')"));
    expect(desktop, contains('_TimesheetGroupTableHeader'));
    expect(desktop, contains("label: const Text('Группы')"));
    expect(manager, contains("'Создать группу'"));
    expect(manager, contains("'Название группы'"));
    expect(manager, contains("'Сотрудники · выбрано"));
  });

  test('database keeps timesheet groups company scoped and admin managed', () {
    final migration = File(
      'supabase/migrations/20260820161000_timesheet_employee_groups.sql',
    ).readAsStringSync();

    expect(migration, contains('create table if not exists public.timesheet_groups'));
    expect(
      migration,
      contains('create table if not exists public.timesheet_group_members'),
    );
    expect(migration, contains('public.current_user_company_id()'));
    expect(migration, contains("v_role <> 'admin'"));
    expect(
      migration,
      contains('timesheet_group_members_company_employee_uidx'),
    );
    expect(migration, contains('list_timesheet_groups'));
    expect(migration, contains('save_timesheet_group'));
    expect(migration, contains('delete_timesheet_group'));
  });
}
