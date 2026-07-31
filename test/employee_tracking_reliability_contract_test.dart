import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('неотправленные координаты сохраняются локально и восстанавливаются', () {
    final runtime = File(
      'lib/features/employee/data/employee_shift_runtime.dart',
    ).readAsStringSync();
    final localStore = File(
      'lib/features/employee/data/employee_route_local_store.dart',
    ).readAsStringSync();

    expect(runtime, contains('EmployeeRouteLocalStore'));
    expect(runtime, contains('_maximumBatchSize = 100'));
    expect(runtime, contains('_flushAllPending'));
    expect(runtime, contains('await _localStore.load'));
    expect(runtime, contains('await _localStore.save'));
    expect(localStore, contains('pending_points'));
    expect(localStore, contains('pending_gaps'));
    expect(localStore, contains('SharedPreferences.getInstance'));
  });

  test('разрывы фоновой записи фиксируются и показываются руководителю', () {
    final runtime = File(
      'lib/features/employee/data/employee_shift_runtime.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/employee/data/employee_shift_action_repository.dart',
    ).readAsStringSync();
    final report = File(
      'lib/features/reports/presentation/employee_routes_report_screen.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260731070000_employee_tracking_gaps.sql',
    ).readAsStringSync();

    expect(runtime, contains("'application_interrupted'"));
    expect(runtime, contains("'location_service_disabled'"));
    expect(runtime, contains("'permission_missing'"));
    expect(runtime, contains('_checkTrackingHealth'));
    expect(repository, contains('record_employee_tracking_gap'));
    expect(repository, contains('fetch_employee_tracking_gaps'));
    expect(repository, contains('List<EmployeeTrackingGap> get allGaps'));
    expect(report, contains("'Обнаружено разрывов:"));
    expect(report, contains('_gapTitle'));
    expect(migration, contains('public.employee_tracking_gaps'));
    expect(migration, contains('security definer'));
    expect(migration, contains('revoke all'));
  });

  test('у сотрудника есть профиль и только личные настройки роли', () {
    final platform = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final employeeSettings = File(
      'lib/features/employee/presentation/employee_location_settings_screen.dart',
    ).readAsStringSync();

    expect(platform, contains("label: 'Профиль'"));
    expect(platform, contains('ProfileScreen(profile: contentProfile)'));
    expect(profile, contains("title: 'История задач'"));
    expect(profile, contains("title: 'Настройки'"));
    expect(settings, contains('if (profile.isEmployee)'));
    expect(settings, contains("'Геолокация рабочего дня'"));
    expect(employeeSettings, contains('Локально ожидают отправки'));
    expect(employeeSettings, contains('runtime.openSettings'));
    expect(employeeSettings, contains('runtime.openLocationSettings'));
  });
}
