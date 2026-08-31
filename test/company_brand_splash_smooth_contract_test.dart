import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('company splash gives AppСтрой and company equal halves', () {
    final gate = File(
      'lib/features/company/presentation/company_brand_splash_gate_smooth.dart',
    ).readAsStringSync();
    final scene = File(
      'lib/features/company/presentation/stroy_na_veka_logo_scene_smooth.dart',
    ).readAsStringSync();
    final host = File(
      'lib/features/company/presentation/company_brand_splash_host.dart',
    ).readAsStringSync();

    expect(gate, contains('Duration(milliseconds: 2800)'));
    expect(gate, contains('t / 0.50'));
    expect(gate, contains('(animation.value - 0.50) / 0.50'));
    expect(gate, contains('SmoothStroyNaVekaLogoScene'));
    expect(host, contains('SmoothCompanyBrandSplashGate'));
  });

  test('smooth company scene avoids expensive per-frame path metrics', () {
    final scene = File(
      'lib/features/company/presentation/stroy_na_veka_logo_scene_smooth.dart',
    ).readAsStringSync();

    expect(scene, contains('super(repaint: animation)'));
    expect(scene, contains('RepaintBoundary'));
    expect(scene, isNot(contains('computeMetrics')));
    expect(scene, isNot(contains('Image.asset')));
  });
}
