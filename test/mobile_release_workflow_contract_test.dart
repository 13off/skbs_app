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
    expect(marker, contains('version: 1.3.2+6'));
    expect(marker, contains('previous mobile release: 1.3.1+5'));
    expect(marker, contains('role-specific platforms'));
    expect(marker, contains('unified employee cabinet'));
    expect(marker, contains('adaptive dark theme'));
    expect(marker, contains('Android APK and unsigned iOS IPA'));
  });
}
