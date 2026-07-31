from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Expected fragment not found in {path}: {old[:140]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


runtime_path = 'lib/features/employee/data/employee_shift_runtime.dart'
replace_once(
    runtime_path,
    "  Future<void> preparePermission() async {\n    try {\n",
    "  Future<void> preparePermission() async {\n    if (kIsWeb) return;\n    try {\n",
)
replace_once(
    runtime_path,
    """      final permission = await _permissionWithoutPrompt();
      if (_canTrack(permission) &&
          await Geolocator.isLocationServiceEnabled()) {
        await _startPositionStream();
      } else {
        _beginGap(
          reason: permission == LocationPermission.always
              ? 'location_service_disabled'
              : 'permission_missing',
          details: permission == LocationPermission.always
              ? 'На телефоне отключена геолокация.'
              : 'У приложения нет постоянного доступа к геопозиции.',
        );
        _startTimers();
      }
""",
    """      if (kIsWeb) {
        await _startPositionStream();
      } else {
        final permission = await _permissionWithoutPrompt();
        if (_canTrack(permission) &&
            await Geolocator.isLocationServiceEnabled()) {
          await _startPositionStream();
        } else {
          _beginGap(
            reason: permission == LocationPermission.always
                ? 'location_service_disabled'
                : 'permission_missing',
            details: permission == LocationPermission.always
                ? 'На телефоне отключена геолокация.'
                : 'У приложения нет постоянного доступа к геопозиции.',
          );
          _startTimers();
        }
      }
""",
)
replace_once(
    runtime_path,
    """      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
""",
    "      final position = await _requiredPosition();\n",
)
replace_once(
    runtime_path,
    """      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
""",
    "      final position = await _requiredPosition();\n",
)
replace_once(
    runtime_path,
    """  Future<LocationPermission> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
""",
    """  Future<LocationPermission> _ensurePermission() async {
    // Safari/PWA может не поддерживать Permissions API и возвращать denied,
    // хотя navigator.geolocation способен показать системный запрос.
    // На web доступ подтверждается только успешно полученной координатой.
    if (kIsWeb) return LocationPermission.whileInUse;

    if (!await Geolocator.isLocationServiceEnabled()) {
""",
)
replace_once(
    runtime_path,
    """  LocationSettings _streamSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      );
    }
""",
    """  Future<Position> _requiredPosition() async {
    if (!kIsWeb) {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const WebSettings(
          accuracy: LocationAccuracy.high,
          maximumAge: Duration(seconds: 30),
          timeLimit: Duration(seconds: 45),
        ),
      );
    } on TimeoutException {
      return Geolocator.getCurrentPosition(
        locationSettings: const WebSettings(
          accuracy: LocationAccuracy.medium,
          maximumAge: Duration(minutes: 1),
          timeLimit: Duration(seconds: 30),
        ),
      );
    }
  }

  LocationSettings _streamSettings() {
    if (kIsWeb) {
      return const WebSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
        maximumAge: Duration(seconds: 30),
        timeLimit: Duration(seconds: 60),
      );
    }
""",
)
replace_once(
    runtime_path,
    """  Future<void> _checkTrackingHealth() async {
    if (!state.value.isActive || _boundEmployeeId.isEmpty) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
""",
    """  Future<void> _checkTrackingHealth() async {
    if (!state.value.isActive || _boundEmployeeId.isEmpty) return;
    try {
      if (kIsWeb) {
        final lastCapturedAt = _lastCapturedAt;
        if (lastCapturedAt != null &&
            DateTime.now().difference(lastCapturedAt) >= _gapThreshold) {
          _beginGap(
            reason: 'tracking_interruption',
            details: 'Web-приложение перестало передавать координаты.',
            startedAt: lastCapturedAt,
          );
          await _positionSubscription?.cancel();
          _positionSubscription = null;
        }
        if (_positionSubscription == null) await _startPositionStream();
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
""",
)

home_path = 'lib/features/employee/presentation/employee_home_screen.dart'
replace_once(home_path, "import '../data/employee_shift_web_fallback_repository.dart';\n", '')
replace_once(
    home_path,
    """    } on EmployeeLocationPermissionException catch (error) {
      if (!mounted) return;
      if (kIsWeb) {
        await startWebWithoutLocation(employeeId);
      } else {
        message(error.message);
        if (error.openSettingsRequired) {
          await openSettingsDialog(error.message);
        }
      }
    } catch (error) {
      if (!mounted) return;
      if (kIsWeb && isEmployeeLocationError(error)) {
        await startWebWithoutLocation(employeeId);
      } else {
        message(employeeLocationErrorMessage(error));
      }
""",
    """    } on EmployeeLocationPermissionException catch (error) {
      if (!mounted) return;
      if (kIsWeb) {
        await openWebLocationDialog(error.message);
      } else {
        message(error.message);
        if (error.openSettingsRequired) {
          await openSettingsDialog(error.message);
        }
      }
    } catch (error) {
      if (!mounted) return;
      final text = employeeLocationErrorMessage(error);
      if (kIsWeb && isEmployeeLocationError(error)) {
        await openWebLocationDialog(text);
      } else {
        message(text);
      }
""",
)
replace_once(
    home_path,
    """    } catch (error) {
      if (!mounted) return;
      if (kIsWeb && isEmployeeLocationError(error)) {
        await finishWebWithoutLocation(widget.selectedEmployeeId.value);
      } else {
        message(employeeLocationErrorMessage(error));
      }
    } finally {
""",
    """    } catch (error) {
      if (!mounted) return;
      final text = employeeLocationErrorMessage(error);
      if (kIsWeb && isEmployeeLocationError(error)) {
        await openWebLocationDialog(text);
      } else {
        message(text);
      }
    } finally {
""",
)
replace_once(
    home_path,
    """  Future<void> startWebWithoutLocation(String employeeId) async {
    try {
      await EmployeeShiftWebFallbackRepository.startWithoutLocation(
        employeeId: employeeId,
      );
      await runtime.reload(employeeId);
      if (mounted) message('Рабочий день начат');
    } catch (error) {
      if (mounted) message(cleanError(error));
    }
  }

  Future<void> finishWebWithoutLocation(String employeeId) async {
    try {
      await EmployeeShiftWebFallbackRepository.finishWithoutLocation(
        employeeId: employeeId,
      );
      await runtime.reload(employeeId);
      if (mounted) message('Рабочий день завершён');
    } catch (error) {
      if (mounted) message(cleanError(error));
    }
  }

""",
    '',
)
replace_once(
    home_path,
    "  Future<void> openSettingsDialog(String text) async {\n",
    """  Future<void> openWebLocationDialog(String text) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Геопозиция недоступна'),
        content: Text(text),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> openSettingsDialog(String text) async {
""",
)
replace_once(
    home_path,
    """  if (value is TimeoutException) {
    return 'Не удалось определить геопозицию за отведённое время. '
        'Включите точную геопозицию и повторите.';
  }
""",
    """  if (value is TimeoutException) {
    return 'Телефон не передал координату. Проверьте геолокацию и повторите.';
  }
""",
)

repo_path = 'lib/features/employee/data/employee_shift_action_repository.dart'
replace_once(repo_path, "  final double? startLatitude;\n  final double? startLongitude;\n", "  final double startLatitude;\n  final double startLongitude;\n")
replace_once(repo_path, "      startLatitude: _nullableNumber(json['start_latitude']),\n      startLongitude: _nullableNumber(json['start_longitude']),\n", "      startLatitude: _number(json['start_latitude']),\n      startLongitude: _number(json['start_longitude']),\n")

fallback = Path('lib/features/employee/data/employee_shift_web_fallback_repository.dart')
if fallback.exists():
    fallback.unlink()
fallback_test = Path('test/employee_web_shift_fallback_contract_test.dart')
if fallback_test.exists():
    fallback_test.unlink()

Path('supabase/migrations/20260731153500_restore_required_shift_start_location.sql').write_text(
    """begin;

drop function if exists public.start_employee_shift_without_location(uuid, date);
drop function if exists public.finish_employee_shift_without_location(uuid);

alter table public.employee_work_shifts
  alter column start_latitude set not null,
  alter column start_longitude set not null,
  alter column start_accuracy_m set not null;

comment on column public.employee_work_shifts.start_latitude is
  'Реальная широта обязательной начальной точки рабочего дня.';
comment on column public.employee_work_shifts.start_longitude is
  'Реальная долгота обязательной начальной точки рабочего дня.';
comment on column public.employee_work_shifts.start_accuracy_m is
  'Точность обязательной начальной точки рабочего дня.';

commit;
""",
    encoding='utf-8',
)

Path('test/employee_start_location_web_contract_test.dart').write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath =
      'lib/features/employee/presentation/employee_home_screen.dart';
  const runtimePath =
      'lib/features/employee/data/employee_shift_runtime.dart';
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

  test('Safari получает координату напрямую без ненадёжного Permissions API', () {
    final runtime = File(runtimePath).readAsStringSync();
    expect(runtime, contains('if (kIsWeb) return LocationPermission.whileInUse'));
    expect(runtime, contains('WebSettings('));
    expect(runtime, contains('maximumAge: Duration(seconds: 30)'));
    expect(runtime, contains('on TimeoutException'));
    expect(runtime, contains('final position = await _requiredPosition()'));
  });

  test('без стартовой координаты серверная смена снова запрещена', () {
    final migration = File(rollbackMigrationPath).readAsStringSync();
    expect(migration, contains('start_latitude set not null'));
    expect(migration, contains('start_longitude set not null'));
    expect(migration, contains('start_accuracy_m set not null'));
    expect(migration, contains('drop function if exists public.start_employee_shift_without_location'));
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
""",
    encoding='utf-8',
)

Path('tool/apply_strict_web_location_patch.py').unlink()
