import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup splash layers can be temporarily bypassed for diagnostics', () {
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
    final deploy = File('.github/workflows/deploy-web.yml').readAsStringSync();

    // Исходный первый экран AppСтрой остаётся в проекте, но при публикации
    // временно скрывается, чтобы проверить запуск вообще без заставок.
    expect(web, contains('id="app-loader"'));
    expect(web, contains("window.addEventListener('flutter-first-frame'"));
    expect(web, contains('var appStroyVisibleMs = 2000;'));
    expect(
      deploy,
      contains('id="app-loader" style="display:none!important"'),
    );

    expect(main, isNot(contains('binding.deferFirstFrame();')));
    expect(main, isNot(contains('WidgetsBinding.instance.allowFirstFrame();')));
    expect(main, isNot(contains('CircularProgressIndicator')));
    expect(main, isNot(contains('return const AppStroyStartupPhase();')));
    expect(main, contains('return const Scaffold(body: SizedBox.shrink());'));

    // Код обоих экранов не удаляется: после диагностики их можно вернуть.
    expect(startupPhase, contains("'AppСтрой'"));
    expect(startupPhase, contains("'планируй. строй. управляй.'"));
    expect(gate, contains('Duration(milliseconds: 4600)'));
    expect(gate, contains('SmoothStroyNaVekaLogoScene'));
    expect(host, contains('_companySplashTemporarilyDisabled = true'));
  });

  test('Flutter AppСтрой handoff cancels the global viewport scale', () {
    final startupPhase = File(
      'lib/widgets/app_stroy_startup_phase.dart',
    ).readAsStringSync();
    final viewport = File('lib/app/app_scale_viewport.dart').readAsStringSync();

    // Код компенсации сохраняем для будущего возврата заставки.
    expect(viewport, contains('static const double _designCalibration = 0.80;'));
    expect(startupPhase, contains('View.of(context)'));
    expect(startupPhase, contains('logicalViewportWidth / mediaQuery.size.width'));
    expect(startupPhase, contains('return 1 / inheritedViewportScale;'));
    expect(startupPhase, contains('scale: contentScale'));
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
