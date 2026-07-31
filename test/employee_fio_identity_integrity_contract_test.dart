import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('кабинет не принимает другую карточку вместо выбранного сотрудника', () {
    final repository = File(
      'lib/features/employee/data/employee_task_cabinet_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('requestedEmployeeId'));
    expect(repository, contains('result.profile.employeeId != requestedEmployeeId'));
    expect(
      repository,
      contains('Выбранный сотрудник и открытая рабочая карточка не совпадают'),
    );
  });

  test('все вкладки режима сотрудника используют одно ФИО', () {
    final platform = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/employee/presentation/employee_identity_profile_screen.dart',
    ).readAsStringSync();
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(platform, contains('selectedEmployeeId'));
    expect(platform, contains('selectedEmployeeName'));
    expect(platform, contains('data.profile.fullName.trim()'));
    expect(platform, contains('EmployeeIdentityProfileScreen('));
    expect(profile, contains('ФИО берётся из выбранной рабочей карточки.'));
    expect(profile, contains('value: identity.fullName'));
    expect(profile, contains('selectedEmployeeId: widget.selectedEmployeeId'));
    expect(main, contains('initialEmployeeName: previewEmployeeName'));
    expect(main, contains("' · ${employeeName.trim()}'"));
  });

  test('точка маршрута не может принадлежать другому сотруднику', () {
    final migration = File(
      'supabase/migrations/20260731171500_employee_route_identity_integrity.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('unique (company_id, id, employee_id)'),
    );
    expect(
      migration,
      contains('foreign key (company_id, shift_id, employee_id)'),
    );
    expect(
      migration,
      contains(
        'references public.employee_work_shifts (company_id, id, employee_id)',
      ),
    );
    expect(
      migration,
      contains('validate constraint employee_work_shift_points_shift_identity_fkey'),
    );
  });
}
