import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup keeps PWA unique and enables the same two native phases', () {
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

    // Web по-прежнему использует только HTML/PWA AppСтрой как первую фазу.
    expect(webIndex, contains('id="app-loader"'));
    expect(webIndex, contains("var appStroyVisibleMs = 2000;"));
    expect(
      deploySource,
      isNot(contains('id="app-loader" style="display:none!important"')),
    );
    expect(mainSource, contains('if (kIsWeb) return const Scaffold'));

    // На iOS/Android первая Flutter-фаза начинается сразу и мягко проявляется.
    expect(
      mainSource,
      contains('return const AppStroyStartupPhase(animateEntrance: true);'),
    );
    expect(appStroySource, contains('this.animateEntrance = false'));
    expect(appStroySource, contains('TweenAnimationBuilder<double>('));
    expect(appStroySource, contains('Duration(milliseconds: 820)'));
    expect(appStroySource, contains('Curves.easeInOutCubic'));
    expect(appStroySource, contains("'AppСтрой'"));
    expect(appStroySource, contains("'планируй. строй. управляй.'"));

    // После неё общий company gate делает тот же crossfade во вторую фазу.
    expect(hostSource, contains('SmoothCompanyBrandSplashGate('));
    expect(gateSource, contains('Duration(milliseconds: 720)'));
    expect(gateSource, contains('AnimatedOpacity('));
    expect(gateSource, contains('opacity: firstPhaseVisible ? 1 : 0'));
    expect(gateSource, contains('opacity: companyPhaseVisible ? 1 : 0'));
    expect(gateSource, contains('SmoothStroyNaVekaLogoScene'));

    expect(sceneSource, contains('final roofs = _interval(phase, 0.16, 0.78);'));
    expect(sceneSource, contains('Curves.easeInOutCubic'));
    expect(sceneSource, contains('Curves.easeInOutSine'));
    expect(sceneSource, contains('void _roofReveal('));
  });

  test('native OS launch screens do not add a third logo frame', () {
    final ios = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    final android = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final androidDark = File(
      'android/app/src/main/res/drawable/launch_background_dark.xml',
    ).readAsStringSync();
    final android31 = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();

    expect(ios, isNot(contains('image="LaunchImage"')));
    expect(ios, contains('systemColor="systemBackgroundColor"'));
    expect(android, isNot(contains('@drawable/app_icon_foreground')));
    expect(androidDark, isNot(contains('@drawable/app_icon_foreground_dark')));
    expect(
      android31,
      contains(
        '<item name="android:windowSplashScreenAnimatedIcon">@android:color/transparent</item>',
      ),
    );
  });
}
