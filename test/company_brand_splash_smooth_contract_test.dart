import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup shows only AppСтрой then one smooth company phase', () {
    final gate = File(
      'lib/features/company/presentation/company_brand_splash_gate_smooth.dart',
    ).readAsStringSync();
    final host = File(
      'lib/features/company/presentation/company_brand_splash_host.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final startupPhase = File(
      'lib/widgets/app_stroy_startup_phase.dart',
    ).readAsStringSync();
    final web = File('web/index.html').readAsStringSync();

    expect(web, contains('id="app-loader"'));
    expect(web, contains("window.addEventListener('flutter-first-frame'"));
    expect(web, contains('var appStroyVisibleMs = 2000;'));
    expect(web, isNot(contains('switchToCompanyFallback')));
    expect(web, isNot(contains('companyFallbackShown')));
    expect(web, isNot(contains('Загрузка Строй На Века')));
    expect(web, contains('window.setTimeout(completeAppStroyPhase, appStroyVisibleMs);'));

    expect(main, isNot(contains('binding.deferFirstFrame();')));
    expect(main, isNot(contains('WidgetsBinding.instance.allowFirstFrame();')));
    expect(main, isNot(contains('CircularProgressIndicator')));
    expect(main, contains('return const AppStroyStartupPhase();'));

    expect(startupPhase, contains("'AppСтрой'"));
    expect(startupPhase, contains("'планируй. строй. управляй.'"));
    expect(
      startupPhase,
      isNot(contains("'web/icons/AppStroy-512-v2.png'")),
    );

    expect(gate, contains('Duration(milliseconds: 4600)'));
    expect(gate, contains('CurvedAnimation('));
    expect(gate, contains('curve: Curves.linear'));
    expect(gate, isNot(contains('AlwaysStoppedAnimation<double>(1.0)')));
    expect(gate, contains('SmoothStroyNaVekaLogoScene'));
    expect(gate, contains('? const AppStroyStartupPhase()'));
    expect(gate, isNot(contains('class _AppStroyPhase')));
    expect(gate, isNot(contains('class _AppStroyIdentity')));

    expect(host, contains('Duration(milliseconds: 1200)'));
    expect(host, contains('AppStroyStartupPhase'));
    expect(host, isNot(contains('class _AppStroyStartupPhase')));
    expect(host, isNot(contains("'web/icons/AppStroy-512-v2.png'")));
    expect(host, contains('if (_resolvingCompany)'));
    expect(host, contains('SmoothCompanyBrandSplashGate'));
  });

  test('published AppСтрой splash has no progress line', () {
    final deploy = File('.github/workflows/deploy-web.yml').readAsStringSync();

    expect(deploy, contains("sed -i '/class=\"loader-progress\"/d'"));
  });

  test('splash keeps app mounted underneath while company phase runs', () {
    final gate = File(
      'lib/features/company/presentation/company_brand_splash_gate_smooth.dart',
    ).readAsStringSync();
    final host = File(
      'lib/features/company/presentation/company_brand_splash_host.dart',
    ).readAsStringSync();

    expect(gate, contains('Offstage('));
    expect(gate, contains('offstage: !_complete'));
    expect(gate, contains('TickerMode('));
    expect(gate, contains('child: widget.child'));
    expect(host, contains('Offstage('));
    expect(host, contains('offstage: true'));
    expect(host, contains('TickerMode(enabled: false, child: widget.child)'));
  });

  test('company scene caches vector layers instead of rebuilding bricks per frame', () {
    final scene = File(
      'lib/features/company/presentation/stroy_na_veka_logo_scene_smooth.dart',
    ).readAsStringSync();

    expect(scene, contains('super(repaint: animation)'));
    expect(scene, contains('RepaintBoundary'));
    expect(scene, contains('static final _ScenePictures _scene'));
    expect(scene, contains('ui.Picture'));
    expect(scene, contains('canvas.drawPicture'));
    expect(scene, isNot(contains('computeMetrics')));
    expect(scene, isNot(contains('Image.asset')));
  });

  test('Stroy Na Veka roofs overlap towers and never pop with back easing', () {
    final scene = File(
      'lib/features/company/presentation/stroy_na_veka_logo_scene_smooth.dart',
    ).readAsStringSync();

    expect(scene, contains('final towers = _interval(phase, 0.10, 0.64);'));
    expect(scene, contains('final roofs = _interval(phase, 0.16, 0.78);'));
    expect(scene, contains('void _roofReveal('));
    expect(scene, contains('Curves.easeInOutCubic.transform(progress)'));
    expect(scene, contains('Curves.easeInOutSine.transform(progress)'));
    expect(scene, isNot(contains('Curves.easeOutBack')));
    expect(scene, isNot(contains('lift: 18')));
  });
}
