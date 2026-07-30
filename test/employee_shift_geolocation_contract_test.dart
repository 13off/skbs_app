import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('панель сотрудника содержит только задачи и историю', () {
    final shell = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();

    expect(shell, contains("label: 'Задачи'"));
    expect(shell, contains("label: 'История задач'"));
    expect(shell, contains('PersistentTabController(pageCount: items.length)'));
    expect(shell, contains('EmployeeWorkTaskHistoryScreen'));
    expect(shell, isNot(contains("label: 'Табель'")));
    expect(shell, isNot(contains("label: 'Документы'")));
    expect(shell, isNot(contains("label: 'Команда'")));
    expect(shell, isNot(contains('EmployeeTeamTabScreen')));
    expect(shell, isNot(contains('ProfileScreen')));
  });

  test('начало смены требует геолокацию и включает маршрут', () {
    final service = File(
      'lib/features/employee/data/employee_shift_tracking_service.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/employee/presentation/employee_work_cabinet_screen.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/employee-work-actions/index.ts',
    ).readAsStringSync();

    expect(service, contains('LocationPermission.always'));
    expect(service, contains('ACCESS_BACKGROUND_LOCATION'),
        reason: 'Разрешение Android проверяется манифестом отдельным контрактом');
    expect(service, contains('foregroundNotificationConfig'));
    expect(service, contains('appendRoutePoints'));
    expect(service, contains('finishShift'));
    expect(screen, contains("label: 'Начать смену'"));
    expect(screen, contains("'Завершить рабочий день'"));
    expect(screen, contains('EmployeeWorkTaskHistoryScreen'));
    expect(edge, contains('action === "start_shift"'));
    expect(edge, contains('action === "append_route_points"'));
    expect(edge, contains('action === "finish_shift"'));
    expect(edge, contains('haversineMeters'));
    expect(edge, contains('object_geofences'));
  });

  test('платформы объявляют фоновые разрешения', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();

    expect(android, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(android, contains('android.permission.ACCESS_BACKGROUND_LOCATION'));
    expect(android, contains('android.permission.FOREGROUND_SERVICE_LOCATION'));
    expect(ios, contains('NSLocationWhenInUseUsageDescription'));
    expect(ios, contains('NSLocationAlwaysAndWhenInUseUsageDescription'));
    expect(ios, contains('<string>location</string>'));
  });

  test('маршруты хранятся отдельно от задач и закрыты RLS', () {
    final migration = File(
      'supabase/migrations/20260730183000_employee_shift_routes.sql',
    ).readAsStringSync();
    final routeScreen = File(
      'lib/features/employee/presentation/employee_route_map_screen.dart',
    ).readAsStringSync();

    expect(migration, contains('public.object_geofences'));
    expect(migration, contains('public.employee_work_shifts'));
    expect(migration, contains('public.employee_work_shift_points'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('revoke all'));
    expect(routeScreen, contains('FlutterMap('));
    expect(routeScreen, contains('PolylineLayer('));
    expect(routeScreen, contains('CircleLayer('));
    expect(routeScreen, contains('© OpenStreetMap contributors'));
  });
}
