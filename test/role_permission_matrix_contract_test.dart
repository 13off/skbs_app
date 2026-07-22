import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/developer/models/role_permission_matrix.dart';

void main() {
  test('object override wins over company override and role default', () {
    final center = RolePermissionCenter.fromJson(<String, dynamic>{
      'actor_role': 'developer',
      'roles': <Map<String, dynamic>>[
        <String, dynamic>{'code': 'foreman', 'title': 'Прораб'},
      ],
      'permissions': <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'tasks.view',
          'category': 'Задачи',
          'title': 'Просмотр задач',
          'description': '',
          'supports_object_scope': true,
          'sort_order': 10,
        },
      ],
      'defaults': <Map<String, dynamic>>[
        <String, dynamic>{
          'role_code': 'foreman',
          'permission_code': 'tasks.view',
        },
      ],
      'company_overrides': <Map<String, dynamic>>[
        <String, dynamic>{
          'role_code': 'foreman',
          'permission_code': 'tasks.view',
          'is_allowed': false,
        },
      ],
      'objects': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'object-1',
          'name': 'Объект',
          'is_active': true,
        },
      ],
      'object_overrides': <Map<String, dynamic>>[
        <String, dynamic>{
          'object_id': 'object-1',
          'role_code': 'foreman',
          'permission_code': 'tasks.view',
          'is_allowed': true,
        },
      ],
      'audit': const <dynamic>[],
    });

    expect(
      center.allowed(roleCode: 'foreman', permissionCode: 'tasks.view'),
      isFalse,
    );
    expect(
      center.allowed(
        roleCode: 'foreman',
        permissionCode: 'tasks.view',
        objectId: 'object-1',
      ),
      isTrue,
    );
    expect(
      center.hasOverride(
        roleCode: 'foreman',
        permissionCode: 'tasks.view',
        objectId: 'object-1',
      ),
      isTrue,
    );
  });

  test('admin cannot edit protected system roles', () {
    final center = RolePermissionCenter.fromJson(<String, dynamic>{
      'actor_role': 'admin',
      'roles': const <dynamic>[],
      'permissions': const <dynamic>[],
      'defaults': const <dynamic>[],
      'company_overrides': const <dynamic>[],
      'objects': const <dynamic>[],
      'object_overrides': const <dynamic>[],
      'audit': const <dynamic>[],
    });

    expect(center.canEditRole('owner'), isFalse);
    expect(center.canEditRole('developer'), isFalse);
    expect(center.canEditRole('admin'), isFalse);
    expect(center.canEditRole('foreman'), isTrue);
  });

  test('server migration protects direct access and exposes guarded RPC', () {
    final migration = File(
      'supabase/migrations/20260722211500_role_permission_matrix_backend.sql',
    ).readAsStringSync();
    final mainScreen = File(
      'lib/features/developer/presentation/developer_main_screen.dart',
    ).readAsStringSync();
    final matrixScreen = File(
      'lib/features/developer/presentation/role_permission_matrix_screen.dart',
    ).readAsStringSync();

    expect(migration, contains('company_role_permission_overrides'));
    expect(migration, contains('object_role_permission_overrides'));
    expect(migration, contains('role_permission_audit'));
    expect(migration, contains('role_permission_effective'));
    expect(migration, contains('get_role_permission_center'));
    expect(migration, contains('save_role_permission_override'));
    expect(migration, contains('reset_role_permission_override'));
    expect(
      migration,
      contains(
        'revoke all on public.company_role_permission_overrides from anon, authenticated',
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.get_role_permission_center() to authenticated',
      ),
    );

    expect(mainScreen, contains('static const int pageCount = 6'));
    expect(mainScreen, contains("label: 'Права'"));
    expect(mainScreen, contains('RolePermissionMatrixScreen'));
    expect(matrixScreen, contains('DataTable('));
    expect(matrixScreen, contains("'Вся компания'"));
    expect(matrixScreen, contains('settings_backup_restore_rounded'));
  });
}
