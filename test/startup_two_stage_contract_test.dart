import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup temporarily bypasses both visual splash phases', () {
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

    // Исходная PWA-заставка остаётся в репозитории, но опубликованный build
    // временно скрывает её для чистой диагностики запуска.
    expect(webIndex, contains('id="app-loader"'));
    expect(webIndex, contains("var appStroyVisibleMs = 2000;"));
    expect(
      deploySource,
      contains('id="app-loader" style="display:none!important"'),
    );

    // Flutter-копия первой заставки тоже не должна рисоваться в диагностике.
    expect(mainSource, isNot(contains('return const AppStroyStartupPhase();')));
    expect(
      mainSource,
      contains('return const Scaffold(body: SizedBox.shrink());'),
    );

    // Вторая заставка компании временно bypass-ится, но весь её код сохранён.
    expect(hostSource, contains('_companySplashTemporarilyDisabled = true'));
    expect(hostSource, contains('if (_companySplashTemporarilyDisabled) return widget.child;'));
    expect(gateSource, contains('CurvedAnimation('));
    expect(gateSource, contains('curve: Curves.linear'));
    expect(sceneSource, contains('final roofs = _interval(phase, 0.16, 0.78);'));
    expect(sceneSource, contains('Curves.easeInOutCubic'));
    expect(sceneSource, contains('Curves.easeInOutSine'));
    expect(sceneSource, contains('void _roofReveal('));

    // Ничего не удалено: AppСтрой и «Строй На Века» можно вернуть после теста.
    expect(appStroySource, contains("'AppСтрой'"));
    expect(appStroySource, contains("'планируй. строй. управляй.'"));
    expect(gateSource, contains('SmoothStroyNaVekaLogoScene'));
  });
}
