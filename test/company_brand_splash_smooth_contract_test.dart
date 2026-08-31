import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup uses the existing AppСтрой loader and company splash only', () {
    final gate = File(
      'lib/features/company/presentation/company_brand_splash_gate_smooth.dart',
    ).readAsStringSync();
    final host = File(
      'lib/features/company/presentation/company_brand_splash_host.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final web = File('web/index.html').readAsStringSync();

    expect(web, contains('id="app-loader"'));
    expect(web, contains("window.addEventListener('flutter-first-frame'"));
    expect(main, contains('binding.deferFirstFrame();'));
    expect(main, contains('WidgetsBinding.instance.allowFirstFrame();'));
    expect(gate, contains('Duration(milliseconds: 2400)'));
    expect(gate, contains('Tween<double>(begin: 0.50, end: 1.00)'));
    expect(gate, contains('SmoothStroyNaVekaLogoScene'));
    expect(gate, isNot(contains('class _AppStroyPhase')));
    expect(gate, isNot(contains('class _AppStroyIdentity')));
    expect(host, contains('SmoothCompanyBrandSplashGate'));
  });

  test('splash keeps app mounted underneath while company animation runs', () {
    final gate = File(
      'lib/features/company/presentation/company_brand_splash_gate_smooth.dart',
    ).readAsStringSync();

    expect(gate, contains('Offstage('));
    expect(gate, contains('offstage: !_complete'));
    expect(gate, contains('TickerMode('));
    expect(gate, contains('child: widget.child'));
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
