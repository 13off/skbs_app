import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('PWA bridge uses current Dart JS interop supported by Flutter 3.44', () {
    final service = source('lib/services/pwa_install_service_web.dart');
    expect(service, contains("import 'dart:js_interop';"));
    expect(service, contains("import 'dart:js_interop_unsafe';"));
    expect(service, isNot(contains('dart:js_util')));
    expect(service, isNot(contains("import 'dart:html'")));
    expect(service, contains('JSPromise<JSObject>'));

    final installScreen = source('lib/screens/pwa_install_screen.dart');
    expect(installScreen, contains('Icons.sync_rounded'));
    expect(installScreen, isNot(contains('Icons.auto_sync_rounded')));
  });
}
