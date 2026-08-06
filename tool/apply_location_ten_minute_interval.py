from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Pattern not found for {label}: {old[:180]!r}")
    return text.replace(old, new, 1)


path = Path('lib/features/employee/data/employee_shift_runtime.dart')
text = path.read_text(encoding='utf-8')

text = replace_once(
    text,
    """  static const _maximumBatchSize = 100;
  static const _gapThreshold = Duration(minutes: 3);
  static const _healthCheckInterval = Duration(minutes: 1);
""",
    """  static const _maximumBatchSize = 100;
  static const _captureInterval = Duration(minutes: 10);
  static const _gapThreshold = Duration(minutes: 25);
  static const _healthCheckInterval = Duration(minutes: 2);
  static const _flushInterval = Duration(minutes: 2);
""",
    'tracking constants',
)

text = replace_once(
    text,
    """  StreamSubscription<Position>? _positionSubscription;
  Timer? _flushTimer;
  Timer? _healthTimer;
""",
    """  StreamSubscription<Position>? _positionSubscription;
  Timer? _captureTimer;
  Timer? _flushTimer;
  Timer? _healthTimer;
""",
    'capture timer field',
)

existing_calls = text.count('await _startPositionStream();')
if existing_calls < 3:
    raise SystemExit(f'Expected at least 3 tracking starts, found {existing_calls}')
text = text.replace('await _startPositionStream();', 'await _startTracking();')

text = replace_once(
    text,
    """      return await Geolocator.getCurrentPosition(
        locationSettings: WebSettings(
          accuracy: LocationAccuracy.high,
          maximumAge: Duration(seconds: 30),
          timeLimit: Duration(seconds: 45),
        ),
      );
    } on TimeoutException {
      return Geolocator.getCurrentPosition(
        locationSettings: WebSettings(
          accuracy: LocationAccuracy.medium,
          maximumAge: Duration(minutes: 1),
          timeLimit: Duration(seconds: 30),
        ),
      );
""",
    """      return await Geolocator.getCurrentPosition(
        locationSettings: WebSettings(
          accuracy: LocationAccuracy.medium,
          maximumAge: Duration(minutes: 2),
          timeLimit: Duration(seconds: 30),
        ),
      );
    } on TimeoutException {
      return Geolocator.getCurrentPosition(
        locationSettings: WebSettings(
          accuracy: LocationAccuracy.low,
          maximumAge: Duration(minutes: 5),
          timeLimit: Duration(seconds: 20),
        ),
      );
""",
    'web current position settings',
)

text = replace_once(
    text,
    """  LocationSettings _streamSettings() {
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
        maximumAge: Duration(seconds: 30),
        timeLimit: Duration(seconds: 60),
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
""",
    """  LocationSettings _streamSettings() {
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100,
        maximumAge: Duration(minutes: 2),
        timeLimit: Duration(seconds: 60),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 0,
        intervalDuration: _captureInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'AppСтрой: рабочий день идёт',
          notificationText: 'Приложение работает до завершения рабочего дня',
          notificationChannelName: 'Рабочий день AppСтрой',
          enableWakeLock: false,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        activityType: ActivityType.other,
        distanceFilter: 50,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 50,
    );
  }

  Future<void> _startTracking() async {
    if (kIsWeb) {
      _startTimers();
      _startWebCaptureTimer();
      final lastCapturedAt = _lastCapturedAt;
      if (lastCapturedAt == null ||
          DateTime.now().difference(lastCapturedAt) >= _captureInterval) {
        unawaited(_captureTimedPosition());
      }
      return;
    }
    await _startPositionStream();
  }

  void _startWebCaptureTimer() {
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(_captureInterval, (_) {
      unawaited(_captureTimedPosition());
    });
  }

  Future<void> _captureTimedPosition() async {
    if (!state.value.isActive || _boundEmployeeId.isEmpty) return;
    try {
      final position = await _requiredPosition();
      await _handlePosition(position);
    } catch (error) {
      _beginGap(reason: 'timed_capture_error', details: _error(error));
      unawaited(_saveLocal());
    }
  }

  Future<void> _startPositionStream() async {
""",
    'platform tracking strategy',
)

text = replace_once(
    text,
    """    _flushTimer = Timer.periodic(const Duration(seconds: 45), (_) {
""",
    """    _flushTimer = Timer.periodic(_flushInterval, (_) {
""",
    'flush interval',
)

text = replace_once(
    text,
    """    final point = _point(position);
    if (point.accuracyM > 250 || point.isMock) return;

    _completeOpenGap(point.recordedAt);
""",
    """    final point = _point(position);
    if (point.accuracyM > 120 || point.isMock) return;
    final lastCapturedAt = _lastCapturedAt;
    if (lastCapturedAt != null &&
        point.recordedAt.isBefore(lastCapturedAt.add(_captureInterval))) {
      return;
    }

    _completeOpenGap(point.recordedAt);
""",
    'ten minute capture throttle',
)

text = replace_once(
    text,
    """      if (kIsWeb) {
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
        if (_positionSubscription == null) await _startTracking();
        return;
      }
""",
    """      if (kIsWeb) {
        final lastCapturedAt = _lastCapturedAt;
        if (lastCapturedAt != null &&
            DateTime.now().difference(lastCapturedAt) >= _gapThreshold) {
          _beginGap(
            reason: 'tracking_interruption',
            details: 'Web-приложение не получало контрольную координату.',
            startedAt: lastCapturedAt,
          );
          unawaited(_captureTimedPosition());
        }
        if (_captureTimer == null) _startWebCaptureTimer();
        return;
      }
""",
    'web health check',
)

text = replace_once(
    text,
    """  Future<void> _stopPositionStream() async {
    _flushTimer?.cancel();
""",
    """  Future<void> _stopPositionStream() async {
    _captureTimer?.cancel();
    _captureTimer = null;
    _flushTimer?.cancel();
""",
    'stop capture timer',
)

path.write_text(text, encoding='utf-8')

Path('test/employee_location_sampling_contract_test.dart').write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('employee route stores at most one point every ten minutes', () {
    final source = File(
      'lib/features/employee/data/employee_shift_runtime.dart',
    ).readAsStringSync();

    expect(source, contains('Duration(minutes: 10)'));
    expect(source, contains('intervalDuration: _captureInterval'));
    expect(source, contains('Timer.periodic(_captureInterval'));
    expect(source, contains('lastCapturedAt.add(_captureInterval)'));
    expect(source, isNot(contains('Duration(seconds: 30)')));
  });

  test('battery saving location settings replace navigation accuracy', () {
    final source = File(
      'lib/features/employee/data/employee_shift_runtime.dart',
    ).readAsStringSync();

    expect(source, contains('accuracy: LocationAccuracy.medium'));
    expect(source, contains('enableWakeLock: false'));
    expect(source, contains('pauseLocationUpdatesAutomatically: true'));
    expect(source, contains('point.accuracyM > 120'));
    expect(source, isNot(contains('LocationAccuracy.bestForNavigation')));
  });
}
""",
    encoding='utf-8',
)
