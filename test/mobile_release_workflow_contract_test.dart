import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile release marker dispatches both platform builds', () {
    final workflow = File(
      '.github/workflows/mobile-release.yml',
    ).readAsStringSync();
    final marker = File('release/mobile-release.txt').readAsStringSync();

    expect(workflow, contains('release/mobile-release.txt'));
    expect(workflow, contains('actions: write'));
    expect(workflow, contains("'build-android-apk.yml'"));
    expect(workflow, contains("'build-ios-ipa.yml'"));
    expect(workflow, contains("ref: 'main'"));
    expect(marker, contains('version: 1.3.1+5'));
    expect(marker, contains('previous mobile release: 1.3.0+4'));
    expect(marker, contains('AI chat dark theme contrast'));
    expect(marker, contains('Enter send'));
    expect(marker, contains('Shift+Enter newline'));
  });
}
