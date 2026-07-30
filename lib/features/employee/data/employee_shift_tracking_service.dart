import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'employee_work_action_repository.dart';

enum EmployeeShiftTrackingStatus {
  idle,
  requestingPermission,
  starting,
  tracking,
  finishing,
  error,
}

class EmployeeShiftTrackingSnapshot {
  final EmployeeShiftTrackingStatus status;
  final EmployeeWorkShift? shift;
  final EmployeeLocationPoint? lastPoint;
  final int pendingPointCount;
  final String message;
  final String permissionScope;
  final bool webForegroundOnly;

  const EmployeeShiftTrackingSnapshot({
    required this.status,
    required this.shift,
    required this.lastPoint,
    required this.pendingPointCount,
    required this.message,
    required this.permissionScope,
    required this.webForegroundOnly,
  });

  const EmployeeShiftTrackingSnapshot.idle()
      : status = EmployeeShiftTrackingStatus.idle,
        shift = null,
        lastPoint = null,
        pendingPointCount = 0,
        message = '',
        permissionScope = 'unknown',
        webForegroundOnly = kIsWeb;

  EmployeeWorkShift? get activeShift => shift;
  bool get isActive => shift?.isActive == true;
  bool get isBusy => status == EmployeeShiftTrackingStatus.starting ||
      status == EmployeeShiftTrackingStatus.finishing ||
      status == EmployeeShiftTrackingStatus.requestingPermission;

  EmployeeShiftTrackingSnapshot copyWith({
    EmployeeShiftTrackingStatus? status,
    EmployeeWorkShift? shift,
    bool clearShift = false,
    EmployeeLocationPoint? lastPoint,
    bool clearLastPoint = false,
    int? pendingPointCount,
    String? message,
    String? permissionScope,
    bool? webForegroundOnly,
  }) {
    return EmployeeShiftTrackingSnapshot(
      status: status ?? this.status,
      shift: clearShift ? null : shift ?? this.shift,
      lastPoint: clearLastPoint ? null : lastPoint ?? this.lastPoint,
      pendingPointCount: pendingPointCount ?? this.pendingPointCount,
      message: message ?? this.message,
      permissionScope: permissionScope ?? this.permissionScope,
      webForegroundOnly: webForegroundOnly ?? this.webForegroundOnly,
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

class EmployeeShiftTrackingService {
  EmployeeShiftTrackingService._();

  static final EmployeeShiftTrackingService instance =
      EmployeeShiftTrackingService._();

  static const _activeShiftPreference = 'employee_active_shift_id';
  static const _activeTaskPreference = 'employee_active_shift_task_id';

  final ValueNotifier<EmployeeShiftTrackingSnapshot> state =
      ValueNotifier<EmployeeShiftTrackingSnapshot>(
    const EmployeeShiftTrackingSnapshot.idle(),
  );
  final List<EmployeeLocationPoint> _pendingPoints =
      <EmployeeLocationPoint>[];

  StreamSubscription<Position>? _positionSubscription;
  Timer? _flushTimer;
  bool _isFlushing = false;
  bool _isRestoring = false;

  Future<void> restoreActiveShift() async {
    if (_isRestoring || state.value.isActive) return;
    _isRestoring = true;
    try {
      final serverState = await EmployeeWorkActionRepository.fetchShiftState();
      final shift = serverState.activeShift;
      if (shift == null) {
        await _clearPersistedShift();
        return;
      }
      final permission = await _readPermissionWithoutPrompt();
      state.value = state.value.copyWith(
        status: EmployeeShiftTrackingStatus.tracking,
        shift: shift,
        permissionScope: _permissionScope(permission),
        message: kIsWeb
            ? 'Смена идёт. В браузере маршрут пишется только пока приложение открыто.'
            : 'Смена восстановлена. Маршрут записывается.',
        webForegroundOnly: kIsWeb,
      );
      if (_canTrackWith(permission)) {
        await _startPositionStream();
      } else {
        state.value = state.value.copyWith(
          status: EmployeeShiftTrackingStatus.error,
          message: 'Смена активна, но доступ к геопозиции отключён. '
              'Разрешите доступ «Всегда» и вернитесь в приложение.',
        );
      }
    } catch (error) {
      state.value = state.value.copyWith(
        status: EmployeeShiftTrackingStatus.error,
        message: _errorText(error),
      );
    } finally {
      _isRestoring = false;
    }
  }

  Future<EmployeeWorkShift> startShift(String taskId) async {
    if (state.value.isBusy) {
      throw const EmployeeLocationPermissionException(
        'Дождитесь завершения текущего действия.',
      );
    }
    state.value = state.value.copyWith(
      status: EmployeeShiftTrackingStatus.requestingPermission,
      message: 'Проверяем доступ к геопозиции…',
    );
    try {
      final permission = await _ensurePermissionForShift();
      state.value = state.value.copyWith(
        status: EmployeeShiftTrackingStatus.starting,
        permissionScope: _permissionScope(permission),
        message: 'Определяем положение на объекте…',
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
      final point = _pointFromPosition(position);
      final shift = await EmployeeWorkActionRepository.startShift(
        taskId: taskId,
        point: point,
        permissionScope: _permissionScope(permission),
        trackingMode: kIsWeb ? 'web_foreground' : 'native_background',
      );
      await _persistShift(shift.id, taskId);
      state.value = state.value.copyWith(
        status: EmployeeShiftTrackingStatus.tracking,
        shift: shift,
        lastPoint: point,
        pendingPointCount: 0,
        message: kIsWeb
            ? 'Смена начата. Не закрывайте браузер: в PWA фоновый маршрут не гарантируется.'
            : 'Смена начата. Маршрут записывается в фоне.',
        webForegroundOnly: kIsWeb,
      );
      await _startPositionStream();
      return shift;
    } catch (error) {
      state.value = state.value.copyWith(
        status: EmployeeShiftTrackingStatus.error,
        message: _errorText(error),
      );
      rethrow;
    }
  }

  Future<EmployeeWorkShift> finishShift() async {
    if (!state.value.isActive) {
      throw Exception('Активная смена не найдена');
    }
    state.value = state.value.copyWith(
      status: EmployeeShiftTrackingStatus.finishing,
      message: 'Завершаем смену…',
    );
    try {
      await _flushPending();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
      final point = _pointFromPosition(position);
      final shift = await EmployeeWorkActionRepository.finishShift(point);
      await _stopPositionStream();
      await _clearPersistedShift();
      _pendingPoints.clear();
      state.value = EmployeeShiftTrackingSnapshot(
        status: EmployeeShiftTrackingStatus.idle,
        shift: null,
        lastPoint: point,
        pendingPointCount: 0,
        message: 'Рабочий день завершён.',
        permissionScope: 'unknown',
        webForegroundOnly: kIsWeb,
      );
      return shift;
    } catch (error) {
      state.value = state.value.copyWith(
        status: EmployeeShiftTrackingStatus.error,
        message: _errorText(error),
      );
      rethrow;
    }
  }

  Future<void> openLocationSettings() async {
    if (kIsWeb) return;
    await Geolocator.openAppSettings();
  }

  Future<LocationPermission> _ensurePermissionForShift() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const EmployeeLocationPermissionException(
        'На телефоне выключена геолокация. Включите её и повторите.',
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
            ? 'Доступ к геопозиции запрещён. Откройте настройки AppСтрой и разрешите его.'
            : 'Без геопозиции начать смену нельзя.',
        openSettingsRequired: permission == LocationPermission.deniedForever,
      );
    }
    if (!kIsWeb && permission != LocationPermission.always) {
      throw const EmployeeLocationPermissionException(
        'Для записи маршрута выберите доступ к геопозиции «Всегда». '
        'На Android 11+ это включается в настройках приложения.',
        openSettingsRequired: true,
      );
    }
    return permission;
  }

  Future<LocationPermission> _readPermissionWithoutPrompt() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  bool _canTrackWith(LocationPermission permission) {
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
          notificationTitle: 'AppСтрой: смена идёт',
          notificationText: 'Маршрут записывается до завершения рабочего дня',
          notificationChannelName: 'Контроль рабочей смены',
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
          status: EmployeeShiftTrackingStatus.error,
          message: 'Маршрут временно не записывается: ${_errorText(error)}',
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
    if (!state.value.isActive) return;
    final point = _pointFromPosition(position);
    if (point.accuracyM > 250 || point.isMock) return;
    _pendingPoints.add(point);
    state.value = state.value.copyWith(
      status: EmployeeShiftTrackingStatus.tracking,
      lastPoint: point,
      pendingPointCount: _pendingPoints.length,
      message: kIsWeb
          ? 'Маршрут записывается, пока эта вкладка открыта.'
          : 'Маршрут записывается в фоне.',
    );
    if (_pendingPoints.length >= 5) unawaited(_flushPending());
  }

  EmployeeLocationPoint _pointFromPosition(Position position) {
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
    if (_isFlushing || _pendingPoints.isEmpty || !state.value.isActive) return;
    _isFlushing = true;
    final batch = List<EmployeeLocationPoint>.from(_pendingPoints);
    _pendingPoints.clear();
    try {
      await EmployeeWorkActionRepository.appendRoutePoints(batch);
      state.value = state.value.copyWith(pendingPointCount: _pendingPoints.length);
    } catch (_) {
      _pendingPoints.insertAll(0, batch);
      state.value = state.value.copyWith(
        pendingPointCount: _pendingPoints.length,
        message: 'Нет связи. ${_pendingPoints.length} точек ждут отправки.',
      );
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _stopPositionStream() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _persistShift(String shiftId, String taskId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_activeShiftPreference, shiftId);
    await preferences.setString(_activeTaskPreference, taskId);
  }

  Future<void> _clearPersistedShift() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_activeShiftPreference);
    await preferences.remove(_activeTaskPreference);
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}
