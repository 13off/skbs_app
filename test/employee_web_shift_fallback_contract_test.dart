import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath =
      'lib/features/employee/presentation/employee_home_screen.dart';
  const runtimePath =
      'lib/features/employee/data/employee_shift_runtime.dart';
  const fallbackPath =
      'lib/features/employee/data/employee_shift_web_fallback_repository.dart';
  const migrationPath =
      'supabase/migrations/20260731150500_allow_web_shift_without_initial_location.sql';

  test('PWA starts and finishes the workday without blocking on WebKit GPS', () {
    final home = File(homePath).readAsStringSync();
    final fallback = File(fallbackPath).readAsStringSync();

    expect(home, contains('startWebWithoutLocation(employeeId)'));
    expect(home, contains('finishWebWithoutLocation'));
    expect(home, contains('await runtime.reload(employeeId)'));
    expect(fallback, contains('start_employee_shift_without_location'));
    expect(fallback, contains('finish_employee_shift_without_location'));
  });

  test('native Android still requires a real location and always permission', () {
    final runtime = File(runtimePath).readAsStringSync();

    expect(runtime, contains('Geolocator.getCurrentPosition'));
    expect(runtime, contains('permission != LocationPermission.always'));
    expect(runtime, contains("trackingMode: kIsWeb ? 'web_foreground' : 'native_background'"));
  });

  test('web fallback writes null, never zero or demo coordinates', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('start_latitude drop not null'));
    expect(migration, contains("'unavailable'"));
    expect(migration, contains("'web_foreground'"));
    expect(migration, isNot(contains('start_latitude,\n      0')));
    expect(migration, isNot(contains('start_longitude,\n      0')));
  });
}
