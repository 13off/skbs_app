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

    expect(marker, contains('AppСтрой mobile release'));
    expect(marker, matches(RegExp(r'^version: .+$', multiLine: true)));
    expect(
      marker,
      matches(RegExp(r'^previous mobile release: .+$', multiLine: true)),
    );
    expect(marker, matches(RegExp(r'^features: .+$', multiLine: true)));
    expect(
      marker,
      matches(
        RegExp(
          r'^mobile: .*Android release APK.*unsigned verification iOS IPA.*$',
          multiLine: true,
        ),
      ),
    );
    expect(marker, matches(RegExp(r'^quality gates: .+$', multiLine: true)));
  });
}
