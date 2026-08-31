import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('company launch keeps AppСтрой identity and animates Строй На Века', () {
    final splash = File(
      'lib/features/company/presentation/company_brand_splash_gate.dart',
    ).readAsStringSync();

    expect(splash, contains("'assets/stroi_na_veka.webp'"));
    expect(splash, contains('class _CastleBuildLogo'));
    expect(splash, contains('wallProgress'));
    expect(splash, contains('towerProgress'));
    expect(splash, contains("'AppСтрой'"));
    expect(splash, contains('class _PoweredByAppStroy'));
  });
}
