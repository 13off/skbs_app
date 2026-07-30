import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'employee_shift_action_repository.dart';

enum EmployeeWorkDayStatus {
  idle,
  requestingPermission,
  starting,
  active,
  finishing,
  error,
}

class EmployeeWorkDaySnapshot {
  final EmployeeWorkDayStatus status;
  final String employeeId;
  final EmployeeWorkShift? shift;
  final EmployeeLocationPoint? lastPoint;
  final int pendingPoints;
  final String errorMessage;

  const EmployeeWorkDaySnapshot({
    required this.status,
    required this.employeeId,
    required this.shift,
    required this.lastPoint,
    required this.pendingPoints,
    required this.errorMessage,
  });

  const EmployeeWorkDaySnapshot.idle()
      : status = EmployeeWorkDayStatus.idle,
        employeeId = '',
        shift = null,
        lastPoint = null,
        pendingPoints = 0,
        errorMessage = '';

  bool get isActive => shift?.isActive == true;
  bool get isBusy => status == EmployeeWorkDayStatus.requestingPermission ||
      status == EmployeeWorkDayStatus.starting ||
      status == EmployeeWorkDayStatus.finishing;

  EmployeeWorkDaySnapshot copyWith({
    EmployeeWorkDayStatus? status,
    String? employeeId,
    EmployeeWorkShift? shift,
    bool clearShift = false,
    EmployeeLocationPoint? lastPoint,
    bool clearLastPoint = false,
    int? pendingPoints,
    String? errorMessage,
  }) {
    return EmployeeWorkDaySnapshot(
      status: status ?? this.status,
      employeeId: employeeId ?? this.employeeId,
      shift: clearShift ? null : shift ?? this.shift,
      lastPoint: clearLastPoint ? null : lastPoint ?? this.lastPoint,
      pendingPoints: pendingPoints ?? this.pendingPoints,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class EmployeeLocationPermissionException implements Exception {
  final String message;
  final bool openSettingsRequired;

  const EmployeeLocationPermissionException(
    this.message, {
    this.openSettingsRequired = false,
  });

  @override
  String toString() => message;
}

class EmployeeShiftRuntime {
  EmployeeShiftRuntime._();

  static final EmployeeShiftRuntime instance = EmployeeShiftRuntime._();

  static const _employeePreference = 'employee_work_day_employee_id';
  static const _shiftPreference = 'employee_work_day_shift_id';

  final ValueNotifier<EmployeeWorkDaySnapshot> state =
      ValueNotifier<EmployeeWorkDaySnapshot>(
    const EmployeeWorkDaySnapshot.idle(),
  );

  final List<EmployeeLocationPoint> _pending = <EmployeeLocationPoint>[];
  StreamSubscription<Position>? _positionSubscription;
  Timer? _flushTimer;
  bool _binding = false;
  bool _flushing = false;
  String _boundEmployeeId = '';

  String get employeeId => _boundEmployeeId;

  Future<void> preparePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      // Разрешение окончательно проверяется при начале рабочего дня.
    }
  }

  Future<void> bind(String employeeId) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty || _binding) return;
    if (_boundEmployeeId == cleanEmployeeId && state.value.employeeId == cleanEmployeeId) {
      return;
    }

    _binding = true;
    try {
      await _stopPositionStream();
      _pending.clear();
      _boundEmployeeId = cleanEmployeeId;
      state.value = EmployeeWorkDaySnapshot(
        status: EmployeeWorkDayStatus.idle,
        employeeId: cleanEmployeeId,
        shift: null,
        lastPoint: null,
        pendingPoints: 0,
        errorMessage: '',
      );

      final server = await EmployeeShiftActionRepository.fetchShiftState(
        employeeId: cleanEmployeeId,
      );
      if (_boundEmployeeId != cleanEmployeeId) return;
      final shift = server.activeShift;
      if (shift == null) {
        await _clearPersisted();
        return;
      }

      state.value = state.value.copyWith(
        status: EmployeeWorkDayStatus.active,
        shift: shift,
        errorMessage: '',
      );
      await _persist(cleanEmployeeId, shift.id);
      final permission = await _permissionWithoutPrompt();
      if (_canTrack(permission)) await _startPositionStream();
    } catch (error) {
      if (_boundEmployeeId != cleanEmployeeId) return;
      state.value = state.value.copyWith(
        status: EmployeeWorkDayStatus.error,
        errorMessage: _error(error),
      );
    } finally {
      _binding = false;
    }
  }

  Future<EmployeeWorkShift> start(String employeeId) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) throw Exception('Сотрудник не определён');
    if (_boundEmployeeId != cleanEmployeeId) await bind(cleanEmployeeId);
    if (state.value.isActive) return state.value.shift!;
    if (state.value.isBusy) {
      throw const EmployeeLocationPermissionException(
        'Дождитесь завершения текущего действия.',
      );
    }

    state.value = state.value.copyWith(
      status: EmployeeWorkDayStatus.requestingPermission,
      errorMessage: '',
    );
    try {
      final permission = await _ensurePermission();
      state.value = state.value.copyWith(status: EmployeeWorkDayStatus.starting);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
      final point = _point(position);
      final shift = await EmployeeShiftActionRepository.startShift(
        employeeId: cleanEmployeeId,
        point: point,
        permissionScope: _permissionScope(permission),
        trackingMode: kIsWeb ? 'web_foreground' : 'native_background',
      );
      if (_boundEmployeeId != cleanEmployeeId) {
        throw Exception('Выбранный сотрудник изменился');
      }
      state.value = state.value.copyWith(
        status: EmployeeWorkDayStatus.active,
        shift: shift,
        lastPoint: point,
        pendingPoints: 0,
        errorMessage: '',
      );
      await _persist(cleanEmployeeId, shift.id);
      await _startPositionStream();
      return shift;
    } catch (error) {
      state.value = state.value.copyWith(
        status: EmployeeWorkDayStatus.error,
        errorMessage: _error(error),
      );
      rethrow;
    }
  }

  Future<EmployeeWorkShift> finish() async {
    final cleanEmployeeId = _boundEmployeeId;
    if (cleanEmployeeId.isEmpty || !state.value.isActive) {
      throw Exception('Рабочий день не начат');
    }
    if (state.value.isBusy) {
      throw Exception('Дождитесь завершения текущего действия');
    }

    state.value = state.value.copyWith(
      status: EmployeeWorkDayStatus.finishing,
      errorMessage: '',
    );
    try {
      await _flushPending();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
      final point = _point(position);
      final shift = await EmployeeShiftActionRepository.finishShift(
        employeeId: cleanEmployeeId,
        point: point,
      );
      await _stopPositionStream();
      _pending.clear();
      await _clearPersisted();
      state.value = EmployeeWorkDaySnapshot(
        status: EmployeeWorkDayStatus.idle,
        employeeId: cleanEmployeeId,
        shift: null,
        lastPoint: point,
        pendingPoints: 0,
        errorMessage: '',
      );
      return shift;
    } catch (error) {
      state.value = state.value.copyWith(
        status: EmployeeWorkDayStatus.error,
        errorMessage: _error(error),
      );
      rethrow;
    }
  }

  Future<void> openSettings() async {
    if (kIsWeb) return;
    await Geolocator.openAppSettings();
  }

  Future<LocationPermission> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const EmployeeLocationPermissionException(
        'Включите геолокацию на телефоне и повторите.',
        openSettingsRequired: true,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw EmployeeLocationPermissionException(
        permission == LocationPermission.deniedForever
            ? 'Разрешите AppСтрой доступ к геопозиции в настройках телефона.'
            : 'Без доступа к геопозиции начать работу нельзя.',
        openSettingsRequired: permission == LocationPermission.deniedForever,
      );
    }
    if (!kIsWeb && permission != LocationPermission.always) {
      throw const EmployeeLocationPermissionException(
        'Для рабочего дня разрешите AppСтрой доступ к геопозиции всегда.',
        openSettingsRequired: true,
      );
    }
    return permission;
  }

  Future<LocationPermission> _permissionWithoutPrompt() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  bool _canTrack(LocationPermission permission) {
    if (kIsWeb) {
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    }
    return permission == LocationPermission.always;
  }

  String _permissionScope(LocationPermission permission) {
    if (kIsWeb) return 'web_foreground';
    if (permission == LocationPermission.always) return 'always';
    if (permission == LocationPermission.whileInUse) return 'while_in_use';
    return 'unknown';
  }

  LocationSettings _streamSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 20,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'AppСтрой: рабочий день идёт',
          notificationText: 'Приложение работает до завершения рабочего дня',
          notificationChannelName: 'Рабочий день AppСтрой',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 20,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
  }

  Future<void> _startPositionStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _streamSettings(),
    ).listen(
      _handlePosition,
      onError: (Object error, StackTrace stackTrace) {
        state.value = state.value.copyWith(
          status: EmployeeWorkDayStatus.error,
          errorMessage: _error(error),
        );
      },
    );
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_flushPending()),
    );
  }

  void _handlePosition(Position position) {
    if (!state.value.isActive || _boundEmployeeId.isEmpty) return;
    final point = _point(position);
    if (point.accuracyM > 250 || point.isMock) return;
    _pending.add(point);
    state.value = state.value.copyWith(
      status: EmployeeWorkDayStatus.active,
      lastPoint: point,
      pendingPoints: _pending.length,
      errorMessage: '',
    );
    if (_pending.length >= 5) unawaited(_flushPending());
  }

  EmployeeLocationPoint _point(Position position) {
    return EmployeeLocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
      altitudeM: position.altitude,
      speedMps: position.speed,
      headingDeg: position.heading,
      isMock: position.isMocked,
      recordedAt: position.timestamp,
    );
  }

  Future<void> _flushPending() async {
    final employeeId = _boundEmployeeId;
    if (_flushing ||
        employeeId.isEmpty ||
        _pending.isEmpty ||
        !state.value.isActive) {
      return;
    }
    _flushing = true;
    final batch = List<EmployeeLocationPoint>.from(_pending);
    _pending.clear();
    try {
      await EmployeeShiftActionRepository.appendRoutePoints(
        employeeId: employeeId,
        points: batch,
      );
      state.value = state.value.copyWith(pendingPoints: _pending.length);
    } catch (_) {
      if (_boundEmployeeId == employeeId) _pending.insertAll(0, batch);
      state.value = state.value.copyWith(pendingPoints: _pending.length);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _stopPositionStream() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _persist(String employeeId, String shiftId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_employeePreference, employeeId);
    await preferences.setString(_shiftPreference, shiftId);
  }

  Future<void> _clearPersisted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_employeePreference);
    await preferences.remove(_shiftPreference);
  }

  String _error(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}
