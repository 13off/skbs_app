import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final matrix = jsonDecode(
    File('config/role-capability-matrix.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final roles = (matrix['roles'] as List<dynamic>)
      .whereType<Map>()
      .map((value) => Map<String, dynamic>.from(value))
      .toList(growable: false);

  test('role matrix contains every production platform exactly once', () {
    final roleNames = roles.map((item) => item['role']).toList();
    expect(roleNames.toSet().length, roleNames.length);
    expect(
      roleNames.toSet(),
      <String>{'admin', 'developer', 'foreman', 'hr', 'accountant', 'lawyer'},
    );

    for (final role in roles) {
      expect(role['title'].toString().trim(), isNotEmpty);
      expect(role['platform'].toString().trim(), isNotEmpty);
      expect(role['object_scope'], anyOf('company', 'assigned_object'));
      expect(role['capabilities'], isA<List<dynamic>>());
      expect((role['capabilities'] as List<dynamic>), isNotEmpty);
    }
  });

  test('client routes every role to its dedicated platform', () {
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final profile = File(
      'lib/features/auth/models/app_user_profile.dart',
    ).readAsStringSync();

    for (final role in roles) {
      expect(mainScreen, contains(role['platform'].toString()));
      expect(profile, contains("role == '${role['role']}'"));
    }
    expect(profile, contains("role == 'admin' || role == 'developer'"));
    expect(
      profile,
      contains("actualRole == 'admin' || actualRole == 'developer'"),
    );
  });

  test('foreman remains restricted to the assigned object on the server', () {
    final edge = File(
      'supabase/functions/ai-operational-draft/index.ts',
    ).readAsStringSync();

    expect(edge, contains('const isForeman = roles.has("foreman")'));
    expect(
      edge,
      contains('const objectName = isForeman ? assignedObject : requestedObject'),
    );
    expect(edge, contains('Прорабу не назначен объект'));
  });

  test('server keeps profile and membership role compatibility', () {
    final edge = File(
      'supabase/functions/ai-operational-draft/index.ts',
    ).readAsStringSync();
    final accountingRole = roles.firstWhere(
      (role) => role['role'] == 'accountant',
    );

    expect(edge, contains('const roles = new Set([profileRole, membershipRole])'));
    expect(edge, contains('roles.has("accounting")'));
    expect(accountingRole['server_aliases'], contains('accounting'));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
  });

  test('role preview is presentation-only and keeps actual identity', () {
    final profile = File(
      'lib/features/auth/models/app_user_profile.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(matrix['principles'], isA<Map<String, dynamic>>());
    expect(
      (matrix['principles'] as Map<String, dynamic>)[
        'role_preview_never_changes_server_identity'
      ],
      isTrue,
    );
    expect(profile, contains('actualRole: actualRole'));
    expect(mainScreen, contains('RolePreviewController.restore'));
    expect(mainScreen, contains('profile.previewAs('));
  });

  test('documented permissions cover all matrix roles', () {
    final docs = File('docs/roles-and-permissions.md').readAsStringSync();

    for (final role in roles) {
      expect(docs, contains('`${role['role']}`'), reason: role['role'].toString());
    }
    expect(docs, contains('RLS, RPC или Edge Function'));
  });
}
