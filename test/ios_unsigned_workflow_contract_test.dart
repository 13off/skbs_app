import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsigned iOS workflow accepts only completed Xcode signing validation', () {
    final workflow = File(
      '.github/workflows/build-ios-ipa.yml',
    ).readAsStringSync();

    expect(workflow, contains('build_status=${PIPESTATUS[0]}'));
    expect(workflow, contains('build/ios/iphoneos/Runner.app'));
    expect(workflow, contains('[ -f "$app_path/Info.plist" ]'));
    expect(workflow, contains('[ -f "$app_path/Runner" ]'));
    expect(workflow, contains('grep -q "Xcode build done" ios-build.log'));
    expect(
      workflow,
      contains('grep -q "requires a selected Development Team" ios-build.log'),
    );
    expect(workflow, contains('exit "$build_status"'));
  });
}
