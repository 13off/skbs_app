import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('панель сотрудника содержит главную задачи профиль и историю', () {
    final shell = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();

    expect(shell, contains("label: 'Главная'"));
    expect(shell, contains("label: 'Задачи'"));
    expect(shell, contains("label: 'Профиль'"));
    expect(shell, contains('PersistentTabController(pageCount: items.length)'));
    expect(shell, contains('EmployeeHomeScreen'));
    expect(shell, contains('EmployeeTasksScreen'));
    expect(shell, contains('ProfileScreen(profile: contentProfile)'));
    expect(profile, contains('EmployeeWorkTaskHistoryScreen'));
    expect(profile, contains("title: 'История задач'"));
    expect(shell, isNot(contains("label: 'Табель'")));
    expect(shell, isNot(contains("label: 'Документы'")));
    expect(shell, isNot(contains("label: 'Команда'")));
    expect(shell, isNot(contains('EmployeeTeamTabScreen')));
  });

  test('единая кнопка запускает GPS-смену и завершает реальный путь', () {
    final runtime = File(
      'lib/features/employee/data/employee_shift_runtime.dart',
    ).readAsStringSync();
    final home = File(
      'lib/features/employee/presentation/employee_home_screen.dart',
    ).readAsStringSync();
    final workButton = File(
      'lib/features/employee/presentation/premium_round_work_button.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/employee/presentation/employee_simple_work_screen.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/employee-shift-actions/index.ts',
    ).readAsStringSync();

    expect(runtime, contains('LocationPermission.always'));
    expect(runtime, contains('foregroundNotificationConfig'));
    expect(runtime, contains('appendRoutePoints'));
    expect(runtime, contains('finishShift'));
    expect(home, contains('PremiumRoundWorkButton('));
    expect(home, contains('await runtime.finish()'));
    expect(home, contains('active\n                                ? finishDay'));
    expect(home, contains("'Проверить геолокацию'"));
    expect(home, contains("'Отменить ошибочный старт'"));
    expect(workButton, contains("'Начать работу'"));
    expect(workButton, contains("'Завершить работу'"));
    expect(screen, contains('EmployeeWorkTaskHistoryScreen'));
    expect(edge, contains('action === "start_shift"'));
    expect(edge, contains('action === "append_route_points"'));
    expect(edge, contains('action === "finish_shift"'));
    expect(edge, contains('latitude: point.latitude'));
    expect(edge, contains('longitude: point.longitude'));
    expect(edge, isNot(contains('haversineMeters')));
    expect(edge, isNot(contains('object_geofences')));
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

  test('маршрут показывает геозону время точек и честные разрывы', () {
    final migration = File(
      'supabase/migrations/20260730183000_employee_shift_routes.sql',
    ).readAsStringSync();
    final routeScreen = File(
      'lib/features/employee/presentation/employee_route_map_screen.dart',
    ).readAsStringSync();

    expect(migration, contains('public.employee_work_shifts'));
    expect(migration, contains('public.employee_work_shift_points'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('revoke all'));
    expect(routeScreen, contains('FlutterMap('));
    expect(routeScreen, contains('PolylineLayer('));
    expect(routeScreen, contains('CircleLayer('));
    expect(routeScreen, contains('route.allGaps'));
    expect(routeScreen, contains('showModalBottomSheet<void>'));
    expect(routeScreen, contains("'Разрывы геолокации'"));
    expect(routeScreen, contains("'Выходы за пределы объекта'"));
    expect(routeScreen, contains('© OpenStreetMap contributors'));
  });
}
