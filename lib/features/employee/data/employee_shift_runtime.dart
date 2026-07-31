import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'employee_route_local_store.dart';
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
  static const _maximumBatchSize = 100;
  static const _gapThreshold = Duration(minutes: 3);
  static const _healthCheckInterval = Duration(minutes: 1);

  final ValueNotifier<EmployeeWorkDaySnapshot> state =
      ValueNotifier<EmployeeWorkDaySnapshot>(
    const EmployeeWorkDaySnapshot.idle(),
  );

  final EmployeeRouteLocalStore _localStore = EmployeeRouteLocalStore();
  final List<EmployeeLocationPoint> _pending = <EmployeeLocationPoint>[];
  final List<EmployeeTrackingGapDraft> _pendingGaps =
      <EmployeeTrackingGapDraft>[];

  StreamSubscription<Position>? _positionSubscription;
  Timer? _flushTimer;
  Timer? _healthTimer;
  EmployeeTrackingGapDraft? _openGap;
  DateTime? _lastCapturedAt;
  bool _binding = false;
  bool _flushing = false;
  bool _flushingGaps = false;
  bool _savingLocal = false;
  bool _localDirty = false;
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
    if (_boundEmployeeId == cleanEmployeeId &&
        state.value.employeeId == cleanEmployeeId) {
      return;
    }

    _binding = true;
    try {
      await _stopPositionStream();
      _resetMemory();
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
        await _clearPersisted(cleanEmployeeId);
        return;
      }

      final local = await _localStore.load(
        employeeId: cleanEmployeeId,
        shiftId: shift.id,
      );
      _pending.addAll(local.pendingPoints);
      _pendingGaps.addAll(local.pendingGaps);
      _openGap = local.openGap;
      _lastCapturedAt =
          local.lastCapturedAt ?? shift.lastPointAt ?? shift.startedAt;

      final latestPoint = _pending.isEmpty ? null : _pending.last;
      state.value = state.value.copyWith(
        status: EmployeeWorkDayStatus.active,
        shift: shift,
        lastPoint: latestPoint,
        pendingPoints: _pending.length,
        errorMessage: '',
      );
      await _persist(cleanEmployeeId, shift.id);

      final lastCapturedAt = _lastCapturedAt;
      if (lastCapturedAt != null &&
          DateTime.now().difference(lastCapturedAt) >= _gapThreshold) {
        _beginGap(
          reason: 'application_interrupted',
          details:
              'Приложение или системная фоновая служба не передавали координаты.',
          startedAt: lastCapturedAt,
        );
      }

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
      unawaited(_flushGapEvents());
      unawaited(_flushPending());
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
      state.value =
          state.value.copyWith(status: EmployeeWorkDayStatus.starting);
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

      _resetMemory();
      _lastCapturedAt = point.recordedAt;
      state.value = state.value.copyWith(
        status: EmployeeWorkDayStatus.active,
        shift: shift,
        lastPoint: point,
        pendingPoints: 0,
        errorMessage: '',
      );
      await _persist(cleanEmployeeId, shift.id);
      await _saveLocal();
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
    final shift = state.value.shift;
    if (cleanEmployeeId.isEmpty || shift?.isActive != true) {
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
      final flushed = await _flushAllPending();
      if (!flushed) {
        throw Exception(
          'Не удалось отправить сохранённые точки маршрута. '
          'Проверьте интернет и повторите завершение рабочего дня.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
      final point = _point(position);
      _completeOpenGap(point.recordedAt);
      final gapsFlushed = await _flushGapEvents();
      if (!gapsFlushed) {
        throw Exception(
          'Не удалось сохранить сведения о разрывах геолокации. '
          'Проверьте интернет и повторите.',
        );
      }

      final completed = await EmployeeShiftActionRepository.finishShift(
        employeeId: cleanEmployeeId,
        point: point,
      );
      await _stopPositionStream();
      _resetMemory();
      await _clearPersisted(cleanEmployeeId);
      state.value = EmployeeWorkDaySnapshot(
        status: EmployeeWorkDayStatus.idle,
        employeeId: cleanEmployeeId,
        shift: null,
        lastPoint: point,
        pendingPoints: 0,
        errorMessage: '',
      );
      return completed;
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

  Future<void> openLocationSettings() async {
    if (kIsWeb) return;
    await Geolocator.openLocationSettings();
  }

  Future<LocationPermission> currentPermission() {
    return _permissionWithoutPrompt();
  }

  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
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
        distanceFilter: 0,
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
      (position) => unawaited(_handlePosition(position)),
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_handleStreamError(error));
      },
    );
    _startTimers();
  }

  void _startTimers() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) {
        unawaited(_flushPending());
        unawaited(_flushGapEvents());
      },
    );
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      _healthCheckInterval,
      (_) => unawaited(_checkTrackingHealth()),
    );
  }

  Future<void> _handlePosition(Position position) async {
    if (!state.value.isActive || _boundEmployeeId.isEmpty) return;
    final point = _point(position);
    if (point.accuracyM > 250 || point.isMock) return;

    _completeOpenGap(point.recordedAt);
    _pending.add(point);
    _lastCapturedAt = point.recordedAt;
    state.value = state.value.copyWith(
      status: EmployeeWorkDayStatus.active,
      lastPoint: point,
      pendingPoints: _pending.length,
      errorMessage: '',
    );
    unawaited(_saveLocal());
    unawaited(_flushGapEvents());
    if (_pending.length >= 5) unawaited(_flushPending());
  }

  Future<void> _handleStreamError(Object error) async {
    _beginGap(
      reason: 'stream_error',
      details: _error(error),
    );
    state.value = state.value.copyWith(
      status: EmployeeWorkDayStatus.error,
      errorMessage:
          'Геолокация временно недоступна. Приложение повторит подключение.',
    );
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    unawaited(_saveLocal());
  }

  Future<void> _checkTrackingHealth() async {
    if (!state.value.isActive || _boundEmployeeId.isEmpty) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _beginGap(
          reason: 'location_service_disabled',
          details: 'На телефоне отключена геолокация.',
        );
        state.value = state.value.copyWith(
          status: EmployeeWorkDayStatus.error,
          errorMessage: 'На телефоне отключена геолокация.',
        );
        return;
      }

      final permission = await _permissionWithoutPrompt();
      if (!_canTrack(permission)) {
        _beginGap(
          reason: 'permission_missing',
          details: 'У приложения нет постоянного доступа к геопозиции.',
        );
        state.value = state.value.copyWith(
          status: EmployeeWorkDayStatus.error,
          errorMessage: 'Разрешите доступ к геопозиции всегда.',
        );
        return;
      }

      final lastCapturedAt = _lastCapturedAt;
      if (lastCapturedAt != null &&
          DateTime.now().difference(lastCapturedAt) >= _gapThreshold) {
        _beginGap(
          reason: 'tracking_interruption',
          details:
              'Android не передавал координаты. Возможна остановка приложения '
              'или ограничение фоновой работы.',
          startedAt: lastCapturedAt,
        );
        await _positionSubscription?.cancel();
        _positionSubscription = null;
      }
      if (_positionSubscription == null) {
        await _startPositionStream();
      }
    } catch (error) {
      _beginGap(reason: 'health_check_error', details: _error(error));
    }
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

  void _beginGap({
    required String reason,
    required String details,
    DateTime? startedAt,
  }) {
    final shiftId = state.value.shift?.id.trim() ?? '';
    if (shiftId.isEmpty || _openGap != null) return;
    final candidate = startedAt ?? _lastCapturedAt ?? DateTime.now();
    _openGap = EmployeeTrackingGapDraft(
      shiftId: shiftId,
      startedAt: candidate,
      reason: reason,
      details: details,
    );
    unawaited(_saveLocal());
  }

  void _completeOpenGap(DateTime endedAt) {
    final gap = _openGap;
    if (gap == null) return;
    _openGap = null;
    if (endedAt.isAfter(gap.startedAt) &&
        endedAt.difference(gap.startedAt) >= const Duration(minutes: 2)) {
      _pendingGaps.add(gap.complete(endedAt));
    }
    unawaited(_saveLocal());
  }

  Future<bool> _flushGapEvents() async {
    if (_flushingGaps) {
      for (var attempt = 0; attempt < 100 && _flushingGaps; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return _pendingGaps.isEmpty;
    }
    if (_pendingGaps.isEmpty || _boundEmployeeId.isEmpty) {
      return _pendingGaps.isEmpty;
    }
    _flushingGaps = true;
    try {
      while (_pendingGaps.isNotEmpty) {
        final gap = _pendingGaps.first;
        final endedAt = gap.endedAt;
        if (endedAt == null) {
          _pendingGaps.removeAt(0);
          continue;
        }
        try {
          await EmployeeShiftActionRepository.recordTrackingGap(
            employeeId: _boundEmployeeId,
            shiftId: gap.shiftId,
            startedAt: gap.startedAt,
            endedAt: endedAt,
            reason: gap.reason,
            details: gap.details,
          );
          _pendingGaps.removeAt(0);
          await _saveLocal();
        } catch (_) {
          return false;
        }
      }
      return true;
    } finally {
      _flushingGaps = false;
    }
  }

  Future<bool> _flushPending() async {
    final employeeId = _boundEmployeeId;
    if (_flushing ||
        employeeId.isEmpty ||
        _pending.isEmpty ||
        !state.value.isActive) {
      return _pending.isEmpty;
    }

    _flushing = true;
    final take = _pending.length > _maximumBatchSize
        ? _maximumBatchSize
        : _pending.length;
    final batch = List<EmployeeLocationPoint>.from(_pending.take(take));
    _pending.removeRange(0, take);
    await _saveLocal();
    try {
      await EmployeeShiftActionRepository.appendRoutePoints(
        employeeId: employeeId,
        points: batch,
      );
      state.value = state.value.copyWith(pendingPoints: _pending.length);
      await _saveLocal();
      return true;
    } catch (_) {
      if (_boundEmployeeId == employeeId) _pending.insertAll(0, batch);
      state.value = state.value.copyWith(pendingPoints: _pending.length);
      await _saveLocal();
      return false;
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _flushAllPending() async {
    var safety = 0;
    while (_pending.isNotEmpty && safety < 500) {
      safety += 1;
      if (_flushing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        continue;
      }
      if (!await _flushPending()) return false;
    }
    return _pending.isEmpty;
  }

  Future<void> _stopPositionStream() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _healthTimer?.cancel();
    _healthTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _persist(String employeeId, String shiftId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_employeePreference, employeeId);
    await preferences.setString(_shiftPreference, shiftId);
  }

  Future<void> _clearPersisted(String employeeId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_employeePreference);
    await preferences.remove(_shiftPreference);
    await _localStore.clear(employeeId);
  }

  Future<void> _saveLocal() async {
    _localDirty = true;
    if (_savingLocal) return;
    _savingLocal = true;
    try {
      while (_localDirty) {
        _localDirty = false;
        final employeeId = _boundEmployeeId;
        final shiftId = state.value.shift?.id.trim() ?? '';
        if (employeeId.isEmpty || shiftId.isEmpty) continue;
        final points = List<EmployeeLocationPoint>.from(_pending);
        final gaps = List<EmployeeTrackingGapDraft>.from(_pendingGaps);
        final openGap = _openGap;
        final lastCapturedAt = _lastCapturedAt;
        await _localStore.save(
          employeeId: employeeId,
          shiftId: shiftId,
          pendingPoints: points,
          pendingGaps: gaps,
          openGap: openGap,
          lastCapturedAt: lastCapturedAt,
        );
      }
    } finally {
      _savingLocal = false;
    }
  }

  void _resetMemory() {
    _pending.clear();
    _pendingGaps.clear();
    _openGap = null;
    _lastCapturedAt = null;
    _localDirty = false;
  }

  String _error(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}
