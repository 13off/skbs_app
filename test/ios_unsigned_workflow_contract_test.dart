import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsigned iOS workflow accepts only completed Xcode signing validation', () {
    final workflow = File(
      '.github/workflows/build-ios-ipa.yml',
    ).readAsStringSync();

    expect(workflow, contains(r'build_status=${PIPESTATUS[0]}'));
    expect(workflow, contains('build/ios/iphoneos/Runner.app'));
    expect(workflow, contains(r'[ -f "$app_path/Info.plist" ]'.replaceAll(r'\"', '"')));
    expect(workflow, contains(r'[ -f "$app_path/Runner" ]'.replaceAll(r'\"', '"')));
    expect(workflow, contains('grep -q "Xcode build done" ios-build.log'));
    expect(
      workflow,
      contains('grep -q "requires a selected Development Team" ios-build.log'),
    );
    expect(workflow, contains(r'exit "$build_status"'.replaceAll(r'\"', '"')));
  });
}
