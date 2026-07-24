import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web startup normalizes browser locales before Flutter bootstrap', () {
    final source = File('web/index.html').readAsStringSync();

    expect(source, contains('id="appstroy-locale-guard"'));
    expect(source, contains(".replace(/_/g, '-')"));
    expect(source, contains(".replace(/@.*\$/, '')"));
    expect(source, contains('new Intl.Locale(clean)'));
    expect(source, contains('Object.defineProperty(target, key'));
    expect(source, contains('window.appstroyBrowserLocale'));

    final guardIndex = source.indexOf('id="appstroy-locale-guard"');
    final bootstrapIndex = source.indexOf('flutter_bootstrap.js');
    expect(guardIndex, greaterThanOrEqualTo(0));
    expect(bootstrapIndex, greaterThan(guardIndex));
  });
}
