import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile release artifacts publish only to downloads branch', () {
    for (final path in <String>[
      '.github/workflows/build-android-apk.yml',
      '.github/workflows/build-ios-ipa.yml',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('ref: downloads'));
      expect(source, contains('git push origin HEAD:downloads'));
      expect(source, contains('git pull --rebase origin downloads'));
      expect(
        source,
        isNot(contains('repository: 13off/appstroy-web\n          token: \${{ secrets.WEB_DEPLOY_TOKEN }}\n          path: appstroy-web\n\n')),
      );
    }
  });
}
