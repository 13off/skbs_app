import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home coalesces realtime refreshes while its tab is hidden', () {
    final screen = File('lib/screens/home_screen.dart').readAsStringSync();
    final loading = File('lib/screens/home/home_loading.dart').readAsStringSync();

    expect(screen, contains('TickerMode.valuesOf(context).enabled'));
    expect(screen, contains('if (_tabActive) flushDeferredDataChanges();'));
    expect(loading, contains('if (!_tabActive)'));
    expect(loading, contains('_refreshPending = true;'));
    expect(loading, contains('flushDeferredDataChanges()'));
  });

  test('employee directory defers realtime work until tab is active again', () {
    final screen = File('lib/screens/employees_screen.dart').readAsStringSync();
    final controller = File(
      'lib/screens/employees/employee_directory_controller.dart',
    ).readAsStringSync();

    expect(
      screen,
      contains(
        'directoryController.setActive(TickerMode.valuesOf(context).enabled);',
      ),
    );
    expect(controller, contains('void setActive(bool active)'));
    expect(controller, contains('if (!_active)'));
    expect(controller, contains('_refreshPending = true;'));
    expect(controller, contains('unawaited(load());'));
  });
}
