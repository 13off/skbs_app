import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup keeps only AppStroy then ready company branding', () {
    final webIndex = File('web/index.html').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final hostSource = File(
      'lib/features/company/presentation/company_brand_splash_host.dart',
    ).readAsStringSync();
    final gateSource = File(
      'lib/features/company/presentation/company_brand_splash_gate_smooth.dart',
    ).readAsStringSync();
    final appStroySource = File(
      'lib/widgets/app_stroy_startup_phase.dart',
    ).readAsStringSync();

    expect(webIndex, contains("var appStroyVisibleMs = 2000;"));
    expect(webIndex, isNot(contains('switchToCompanyFallback')));
    expect(webIndex, isNot(contains('Загрузка Строй На Века')));
    expect(webIndex, isNot(contains('companyFallbackShown')));

    expect(mainSource, contains('return const AppStroyStartupPhase();'));
    expect(hostSource, contains('const Positioned.fill(child: AppStroyStartupPhase())'));
    expect(gateSource, contains('? const AppStroyStartupPhase()'));
    expect(
      gateSource,
      contains('const AlwaysStoppedAnimation<double>(1.0)'),
    );

    expect(appStroySource, contains("'AppСтрой'"));
    expect(appStroySource, contains("'планируй. строй. управляй.'"));
    expect(
      appStroySource,
      isNot(contains("'web/icons/AppStroy-512-v2.png'")),
    );
  });
}
