import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// This contract also triggers publication of the verified battery-saving build.
void main() {
  test('employee route stores at most one point every ten minutes', () {
    final source = File(
      'lib/features/employee/data/employee_shift_runtime.dart',
    ).readAsStringSync();

    expect(source, contains('Duration(minutes: 10)'));
    expect(source, contains('intervalDuration: _captureInterval'));
    expect(source, contains('Timer.periodic(_captureInterval'));
    expect(source, contains('lastCapturedAt.add(_captureInterval)'));
    expect(
      source,
      isNot(contains('intervalDuration: const Duration(seconds: 30)')),
    );
  });

  test('web and native tracking use battery saving settings', () {
    final source = File(
      'lib/features/employee/data/employee_shift_runtime.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _captureTimedPosition() async'));
    expect(source, contains('accuracy: LocationAccuracy.medium'));
    expect(source, contains('enableWakeLock: false'));
    expect(source, contains('pauseLocationUpdatesAutomatically: true'));
    expect(source, contains('point.accuracyM > 120'));
  });
}
