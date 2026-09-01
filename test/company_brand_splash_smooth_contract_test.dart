import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA stays unique while native uses the same AppStroy first phase', () {
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

    expect(web, contains('id="app-loader"'));
    expect(web, contains("window.addEventListener('flutter-first-frame'"));
    expect(web, contains('var appStroyVisibleMs = 2000;'));
    expect(web, contains('transition:'));
    expect(web, contains('opacity 520ms cubic-bezier(.22,1,.36,1)'));
    expect(web, contains('animation: stageIn 900ms cubic-bezier(.22,1,.36,1) both'));
    expect(
      deploy,
      isNot(contains('id="app-loader" style="display:none!important"')),
    );

    // Web не получает вторую копию AppСтрой, а native запускает её сразу.
    expect(main, contains('if (kIsWeb) return const Scaffold'));
    expect(
      main,
      contains('return const AppStroyStartupPhase(animateEntrance: true);'),
    );
    expect(startupPhase, contains('if (kIsWeb)'));
    expect(
      startupPhase,
      contains('return Scaffold(backgroundColor: AppAdaptivePalette.background);'),
    );
    expect(startupPhase, contains('TweenAnimationBuilder<double>('));
    expect(startupPhase, contains('Duration(milliseconds: 820)'));
    expect(startupPhase, contains("'AppСтрой'"));
    expect(startupPhase, contains("'планируй. строй. управляй.'"));

    expect(host, isNot(contains('_companySplashTemporarilyDisabled')));
    expect(host, contains('SmoothCompanyBrandSplashGate('));
    expect(gate, contains('Duration(milliseconds: 4600)'));
    expect(gate, contains('SmoothStroyNaVekaLogoScene'));
  });

  test('native AppСтрой handoff keeps viewport scale compensation', () {
    final startupPhase = File(
      'lib/widgets/app_stroy_startup_phase.dart',
    ).readAsStringSync();
    final viewport = File('lib/app/app_scale_viewport.dart').readAsStringSync();

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

  test('company splash crossfades in and out over the ready app', () {
    final gate = File(
      'lib/features/company/presentation/company_brand_splash_gate_smooth.dart',
    ).readAsStringSync();
    final host = File(
      'lib/features/company/presentation/company_brand_splash_host.dart',
    ).readAsStringSync();

    expect(gate, contains('Duration(milliseconds: 720)'));
    expect(gate, contains('bool _exiting = false'));
    expect(gate, contains('void _beginExit()'));
    expect(gate, contains('appVisible = _complete || _exiting'));
    expect(gate, contains('AnimatedOpacity('));
    expect(gate, contains('opacity: firstPhaseVisible ? 1 : 0'));
    expect(gate, contains('opacity: companyPhaseVisible ? 1 : 0'));
    expect(gate, contains('curve: Curves.easeInOutCubic'));
    expect(gate, contains('_exitTimer = Timer(_transitionDuration, _finish)'));
    expect(gate, contains('offstage: !appVisible'));
    expect(gate, contains('enabled: appVisible'));
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
