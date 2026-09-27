import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('Windows startup protects and verifies native input availability', () {
    final window = source('windows/runner/win32_window.cpp');
    final header = source('windows/runner/win32_window.h');
    final workflow = source('.github/workflows/build-windows-desktop.yml');

    expect(window, contains('kStartupInputRecoveryWindowMs'));
    expect(window, contains('SetTimer('));
    expect(window, contains('!IsWindowEnabled(window)'));
    expect(window, contains('!HasVisibleOwnedWindow(window)'));
    expect(window, contains('EnableWindow(window, TRUE)'));
    expect(header, contains('created_at_tick_'));

    expect(workflow, contains('IsWindowEnabled'));
    expect(workflow, contains('IsHungAppWindow'));
    expect(workflow, contains('SendMessageTimeout'));
    expect(
      workflow,
      contains('AppStroy main window became disabled during startup.'),
    );
  });
}
