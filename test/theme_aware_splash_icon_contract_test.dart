import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('saved theme is synchronized before and after Flutter starts', () {
    final controller = source('lib/app/theme_controller.dart');
    final platform = source('lib/app/theme_platform_sync.dart');
    final web = source('lib/app/theme_platform_sync_web.dart');
    final io = source('lib/app/theme_platform_sync_io.dart');

    expect(controller, contains("import 'theme_platform_sync.dart';"));
    expect(controller, contains('await AppThemePlatformSync.apply(isDark: isDark)'));
    expect(controller, contains('await AppThemePlatformSync.apply(isDark: value)'));
    expect(platform, contains("if (dart.library.html) 'theme_platform_sync_web.dart'"));
    expect(platform, contains("if (dart.library.io) 'theme_platform_sync_io.dart'"));
    expect(web, contains("@JS('appstroyApplyTheme')"));
    expect(io, contains("MethodChannel('ru.appstroy.skbs/theme')"));
  });

  test('PWA loader and install icon use the saved app theme', () {
    final index = source('web/index.html');
    final lightManifest = source('web/manifest.json');
    final darkManifest = source('web/manifest-dark.json');
    final darkIcon = source('web/icons/app_icon_matte_dark_v2.svg');

    expect(index, contains("'flutter.app_theme_mode'"));
    expect(index, contains('window.appstroyApplyTheme'));
    expect(index, contains('html[data-app-theme="dark"]'));
    expect(index, contains("manifest: 'manifest-dark.json'"));
    expect(index, contains("icon: 'icons/app_icon_matte_dark_v2.svg'"));
    expect(lightManifest, contains('"background_color": "#F3F1EC"'));
    expect(darkManifest, contains('"background_color": "#0E1621"'));
    expect(darkManifest, contains('app_icon_matte_dark_v2.svg'));
    expect(darkIcon, contains('#0E1621'));
    expect(darkIcon, contains('#F5F7FA'));
  });

  test('Android splash and launcher aliases follow the stored Flutter theme', () {
    final activity = source(
      'android/app/src/main/kotlin/ru/appstroy/skbs/MainActivity.kt',
    );
    final manifest = source('android/app/src/main/AndroidManifest.xml');
    final styles = source('android/app/src/main/res/values/styles.xml');
    final styles31 = source('android/app/src/main/res/values-v31/styles.xml');
    final darkLauncher = source(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_dark.xml',
    );

    expect(activity, contains('FlutterSharedPreferences'));
    expect(activity, contains('flutter.app_theme_mode'));
    expect(activity, contains('R.style.LaunchTheme_Dark'));
    expect(activity, contains('applyLauncherIcon(dark)'));
    expect(activity, contains('PackageManager.DONT_KILL_APP'));
    expect(manifest, contains('android:name=".LauncherLight"'));
    expect(manifest, contains('android:name=".LauncherDark"'));
    expect(manifest, contains('android:icon="@mipmap/ic_launcher_dark"'));
    expect(styles, contains('name="LaunchTheme.Dark"'));
    expect(styles, contains('@drawable/launch_background_dark'));
    expect(styles31, contains('android:windowSplashScreenAnimatedIcon'));
    expect(darkLauncher, contains('@color/app_icon_dark_background'));
  });

  test('native theme resources are compiled by a dedicated Android check', () {
    final workflow = source('.github/workflows/android-theme-check.yml');

    expect(workflow, contains('name: Android Theme Check'));
    expect(workflow, contains('flutter build apk --debug'));
    expect(workflow, contains('- android/**'));
    expect(workflow, contains('- lib/app/theme_platform_sync*.dart'));
  });
}
