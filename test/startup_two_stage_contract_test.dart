import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup shows PWA AppStroy then company splash without Flutter duplicate', () {
    final webIndex = File('web/index.html').readAsStringSync();
    final deploySource = File(
      '.github/workflows/deploy-web.yml',
    ).readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final hostSource = File(
      'lib/features/company/presentation/company_brand_splash_host.dart',
    ).readAsStringSync();
    final gateSource = File(
      'lib/features/company/presentation/company_brand_splash_gate_smooth.dart',
    ).readAsStringSync();
    final sceneSource = File(
      'lib/features/company/presentation/stroy_na_veka_logo_scene_smooth.dart',
    ).readAsStringSync();
    final appStroySource = File(
      'lib/widgets/app_stroy_startup_phase.dart',
    ).readAsStringSync();

    // Первая заставка снова публикуется из HTML/PWA.
    expect(webIndex, contains('id="app-loader"'));
    expect(webIndex, contains("var appStroyVisibleMs = 2000;"));
    expect(
      deploySource,
      isNot(contains('id="app-loader" style="display:none!important"')),
    );

    // Первый Flutter-кадр не рисует вторую копию AppСтрой.
    expect(mainSource, isNot(contains('return const AppStroyStartupPhase();')));
    expect(
      mainSource,
      contains('return const Scaffold(body: SizedBox.shrink());'),
    );
    expect(appStroySource, contains('if (kIsWeb)'));
    expect(
      appStroySource,
      contains('return Scaffold(backgroundColor: AppAdaptivePalette.background);'),
    );

    // Второй этап компании снова включён.
    expect(hostSource, isNot(contains('_companySplashTemporarilyDisabled')));
    expect(hostSource, contains('SmoothCompanyBrandSplashGate('));
    expect(gateSource, contains('CurvedAnimation('));
    expect(gateSource, contains('curve: Curves.linear'));
    expect(gateSource, contains('SmoothStroyNaVekaLogoScene'));

    expect(sceneSource, contains('final roofs = _interval(phase, 0.16, 0.78);'));
    expect(sceneSource, contains('Curves.easeInOutCubic'));
    expect(sceneSource, contains('Curves.easeInOutSine'));
    expect(sceneSource, contains('void _roofReveal('));

    // Нативная версия первой заставки остаётся в коде Android/iOS.
    expect(appStroySource, contains("'AppСтрой'"));
    expect(appStroySource, contains("'планируй. строй. управляй.'"));
  });
}
