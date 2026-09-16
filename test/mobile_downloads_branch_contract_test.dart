import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native release files publish through one stable GitHub Release', () {
    final workflows = <String, List<String>>{
      '.github/workflows/build-android-apk.yml': <String>[
        'apk-output/AppStroy-latest.apk',
        'apk-output/AppStroy-latest.sha256',
      ],
      '.github/workflows/build-ios-ipa.yml': <String>[
        'ios-output/AppStroy-latest.ipa',
        'ios-output/AppStroy-iOS-latest.sha256',
      ],
      '.github/workflows/build-windows-desktop.yml': <String>[
        'windows-output/AppStroy-Windows-Setup.exe',
        'windows-output/AppStroy-Windows-latest.zip',
      ],
    };

    for (final entry in workflows.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(source, contains('contents: write'));
      expect(source, contains('appstroy-latest'));
      expect(source, contains('gh release upload'));
      expect(source, contains('--clobber'));
      expect(source, isNot(contains('actions/upload-artifact')));
      for (final asset in entry.value) {
        expect(source, contains(asset));
      }
    }
  });
}
