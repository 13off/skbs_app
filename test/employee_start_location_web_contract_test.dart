import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath =
      'lib/features/employee/presentation/employee_home_screen.dart';
  const runtimePath = 'lib/features/employee/data/employee_shift_runtime.dart';
  const fallbackPath =
      'lib/features/employee/data/employee_shift_web_fallback_repository.dart';
  const rollbackMigrationPath =
      'supabase/migrations/20260731153500_restore_required_shift_start_location.sql';

  test('рабочий день на web начинается только через runtime с координатой', () {
    final home = File(homePath).readAsStringSync();
    expect(home, contains('await runtime.start(employeeId)'));
    expect(home, contains('openWebLocationDialog'));
    expect(home, isNot(contains('startWebWithoutLocation')));
    expect(home, isNot(contains('EmployeeShiftWebFallbackRepository')));
    expect(File(fallbackPath).existsSync(), isFalse);
  });

  test(
    'Safari получает координату напрямую без ненадёжного Permissions API',
    () {
      final runtime = File(runtimePath).readAsStringSync();
      expect(
        runtime,
        contains('if (kIsWeb) return LocationPermission.whileInUse'),
      );
      expect(runtime, contains('WebSettings('));
      expect(runtime, contains('maximumAge: Duration(minutes: 2)'));
      expect(runtime, contains('maximumAge: Duration(minutes: 5)'));
      expect(runtime, contains('accuracy: LocationAccuracy.medium'));
      expect(runtime, contains('accuracy: LocationAccuracy.low'));
      expect(runtime, contains('on TimeoutException'));
      expect(runtime, contains('final position = await _requiredPosition()'));
      expect(runtime, contains('Timer.periodic(_captureInterval'));
    },
  );

  test('без стартовой координаты серверная смена снова запрещена', () {
    final migration = File(rollbackMigrationPath).readAsStringSync();
    expect(migration, contains('start_latitude set not null'));
    expect(migration, contains('start_longitude set not null'));
    expect(migration, contains('start_accuracy_m set not null'));
    expect(
      migration,
      contains(
        'drop function if exists public.start_employee_shift_without_location',
      ),
    );
  });

  test('сырая ошибка браузера не показывается как object Object', () {
    final home = File(homePath).readAsStringSync();
    expect(home, contains("normalized == '[object object]'"));
    expect(home, contains("normalized.startsWith('instance of ')"));
    expect(home, contains('PermissionDeniedException'));
    expect(home, contains('LocationServiceDisabledException'));
    expect(home, contains('TimeoutException'));
    expect(home, isNot(contains('На iPhone разрешите геопозицию')));
  });
}
