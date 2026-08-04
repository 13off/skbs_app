import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared bottom navigation remains genuinely translucent', () {
    final source = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();

    expect(source, contains('Color(0x66232C35)'));
    expect(source, contains('Color(0x66F1F4F7)'));
    expect(source, contains('Color(0xB3353B42)'));
    expect(source, contains('Color(0x992C3640)'));
    expect(source, contains('Color(0x8011171E)'));
    expect(source, contains('blur: true'));
    expect(source, contains('blurSigma: isDesktop ? 24 : 20'));
    expect(source, isNot(contains('Color(0xFF232C35)')));
    expect(source, isNot(contains('Color(0xF7353B42)')));
  });
}
