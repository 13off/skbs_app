import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('company launch keeps AppСтрой identity and builds Строй На Века as scene', () {
    final splash = File(
      'lib/features/company/presentation/company_brand_splash_gate.dart',
    ).readAsStringSync();
    final scene = File(
      'lib/features/company/presentation/stroy_na_veka_logo_scene.dart',
    ).readAsStringSync();

    expect(splash, contains('StroyNaVekaLogoScene'));
    expect(splash, isNot(contains("'assets/stroi_na_veka.webp'")));
    expect(splash, contains("'AppСтрой'"));
    expect(splash, contains("'Компания в AppСтрой'"));
    expect(scene, contains('class StroyNaVekaLogoScene'));
    expect(scene, contains('_drawCentralWall'));
    expect(scene, contains('_drawTower'));
    expect(scene, contains('_drawRoofs'));
    expect(scene, contains('_drawTitleBlock'));
    expect(scene, isNot(contains('Image.asset')));
  });
}
