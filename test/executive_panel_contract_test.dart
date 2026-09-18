import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260918130000_add_executive_readonly_role.sql';

  test('executive panel keeps exactly chat and payment tabs', () {
    final screen = File(
      'lib/features/executive/presentation/executive_main_screen.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/auth/models/app_user_profile.dart',
    ).readAsStringSync();

    expect(profile, contains("static const String executiveRole = 'executive'"));
    expect(profile, contains("static const String executiveRoleTitle = 'Повелитель'"));
    expect(screen, contains("label: 'Чат'"));
    expect(screen, contains("label: 'Оплата'"));
    expect(screen, contains('pageCount: 2'));
  });

  test('executive data layer stays read only', () {
    final repository = File(
      'lib/features/executive/data/executive_panel_repository.dart',
    ).readAsStringSync();

    expect(repository, isNot(contains('.insert(')));
    expect(repository, isNot(contains('.update(')));
    expect(repository, isNot(contains('.delete(')));
    expect(repository, contains("eq('company_id', cleanCompanyId)"));
    expect(repository, contains('fetchPaymentSummary'));
    expect(repository, contains('fetchEmployeePaymentDetails'));
  });

  test('executive role receives view permissions only', () {
    final migration = File(migrationPath).readAsStringSync();

    const requiredViews = <String>[
      'objects.view',
      'tasks.view',
      'employees.view',
      'attendance.view',
      'accounting.directory.view',
      'accounting.attendance.view',
      'accounting.payments.view',
    ];
    for (final permission in requiredViews) {
      expect(
        migration,
        contains("('executive', '$permission')"),
        reason: 'Missing executive read permission: $permission',
      );
    }

    const forbiddenWrites = <String>[
      'objects.create',
      'objects.edit',
      'objects.archive',
      'objects.delete',
      'tasks.create',
      'tasks.edit',
      'tasks.delete',
      'tasks.assignees.manage',
      'tasks.photos.manage',
      'employees.create',
      'employees.edit',
      'employees.archive',
      'employees.delete',
      'attendance.edit',
      'attendance.delete',
      'accounting.payments.edit',
      'accounting.receipts.edit',
    ];
    for (final permission in forbiddenWrites) {
      expect(
        migration,
        isNot(contains("('executive', '$permission')")),
        reason: 'Executive must stay read only: $permission',
      );
    }
  });

  test('executive can be assigned through mobile desktop and invite flow', () {
    final mobile = File(
      'lib/features/company/presentation/mobile_company_management_screen.dart',
    ).readAsStringSync();
    final desktop = File(
      'lib/features/company/presentation/desktop_company_user_dialogs.dart',
    ).readAsStringSync();
    final companyRepository = File(
      'lib/features/company/data/company_repository.dart',
    ).readAsStringSync();
    final invite = File(
      'supabase/functions/invite-company-member-core/index.ts',
    ).readAsStringSync();
    final migration = File(migrationPath).readAsStringSync();

    expect(mobile, contains("'executive'"));
    expect(mobile, contains("value: 'executive'"));
    expect(desktop, contains("'executive'"));
    expect(desktop, contains("value: 'executive'"));
    expect(companyRepository, contains("return 'Повелитель';"));
    expect(invite, contains('"executive"'));
    expect(migration, contains("'executive'::text"));
    expect(migration, contains("'executive'"));
  });

  test('executive keeps its role and company-wide read scope', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(
      migration,
      contains("public.current_user_role() in ('estimator', 'executive')"),
    );
    expect(
      migration,
      contains("when v_membership_role = 'owner' then 'admin'"),
    );
    expect(migration, contains("else v_membership_role"));
    expect(
      migration,
      contains("when 'executive' then 'executive'"),
    );
  });

  test('executive is visible but protected in permission center', () {
    final migration = File(migrationPath).readAsStringSync();
    final matrixModel = File(
      'lib/features/developer/models/role_permission_matrix.dart',
    ).readAsStringSync();

    expect(
      migration,
      contains("jsonb_build_object('code','executive','title','Повелитель')"),
    );
    expect(matrixModel, contains("roleCode == 'executive'"));
  });

  test('payment filters keep archived objects available', () {
    final screen = File(
      'lib/features/executive/presentation/executive_main_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('fetchArchivedObjectNames'));
    expect(screen, contains('(архив)'));
  });

  test('payment list can be copied grouped by object', () {
    final screen = File(
      'lib/features/executive/presentation/executive_main_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('Скопировать по объектам'));
    expect(screen, contains('Итого по объекту:'));
    expect(screen, contains('groupByObject'));
  });

  test('share editing is local clipboard state only', () {
    final screen = File(
      'lib/features/executive/presentation/executive_main_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('shareAmountControllers'));
    expect(screen, contains('Редактировать для отправки'));
    expect(screen, contains('Clipboard.setData'));
    expect(screen, contains('Выплаты и начисления в системе не меняются.'));
  });
}
