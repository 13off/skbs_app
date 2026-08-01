import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('карта не соединяет пропуски и большие скачки прямой линией', () {
    final route = File(
      'lib/features/employee/presentation/employee_route_map_screen.dart',
    ).readAsStringSync();

    expect(route, contains('List<List<EmployeeLocationPoint>> _routeSegments'));
    expect(route, contains('EmployeeRouteDay.inferredGapThreshold'));
    expect(route, contains('meters >= 500'));
    expect(route, contains('recordedGap'));
    expect(route, contains('result.add(current)'));
  });

  test('руководитель видит время точки разрывы и выходы с объекта', () {
    final route = File(
      'lib/features/employee/presentation/employee_route_map_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/employee/data/employee_route_analysis_repository.dart',
    ).readAsStringSync();

    expect(route, contains("'Нажмите на маршрут — увидите время'"));
    expect(route, contains('_dateTime(point.recordedAt)'));
    expect(route, contains("'Относительно объекта'"));
    expect(route, contains("'Перед этой точкой координат не было"));
    expect(route, contains("'Основной рабочий интервал"));
    expect(route, contains('_outsideEpisodes'));
    expect(repository, contains("'get_employee_route_geofences'"));
  });

  test('проверка GPS не создаёт смену, а ночной старт требует выбора', () {
    final home = File(
      'lib/features/employee/presentation/employee_home_screen.dart',
    ).readAsStringSync();

    expect(home, contains('Future<void> checkCurrentLocation()'));
    expect(home, contains('Geolocator.getCurrentPosition'));
    expect(home, contains('Future<bool> confirmUnusualStartTime()'));
    expect(home, contains('now.hour >= 5 && now.hour < 22'));
    expect(home, contains("'Начать ночную смену или только проверить"));
    expect(home, contains("'Проверить геолокацию'"));
    expect(home, contains("'Начать смену'"));
  });

  test('ошибочный старт отменяется только быстро и без рабочего маршрута', () {
    final migration = File(
      'supabase/migrations/20260801140500_route_timeline_and_shift_safety.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/features/employee/data/employee_route_analysis_repository.dart',
    ).readAsStringSync();
    final home = File(
      'lib/features/employee/presentation/employee_home_screen.dart',
    ).readAsStringSync();

    expect(migration, contains('public.cancel_recent_employee_shift'));
    expect(migration, contains("interval '10 minutes'"));
    expect(migration, contains('route_point_count, 0) > 30'));
    expect(migration, contains("status = 'cancelled'"));
    expect(migration, contains('security definer'));
    expect(repository, contains("'cancel_recent_employee_shift'"));
    expect(home, contains('cancelAccidentalStart'));
    expect(home, contains('await runtime.reload(employeeId)'));
  });
}
