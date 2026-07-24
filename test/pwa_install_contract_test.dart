import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void containsAll(String path, Iterable<String> fragments) {
  final contents = source(path);
  for (final fragment in fragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный PWA-фрагмент "$fragment" отсутствует в $path',
    );
  }
}

void main() {
  test('веб-версия устанавливается как приложение на телефон и компьютер', () {
    containsAll('web/manifest.json', const [
      '"display": "standalone"',
      '"display_override"',
      '"orientation": "any"',
      '"business"',
      '"productivity"',
    ]);
    containsAll('web/index.html', const [
      'beforeinstallprompt',
      'appstroyCanInstallPwa',
      'appstroyInstallPwa',
      'appinstalled',
    ]);
    containsAll('lib/services/pwa_install_service.dart', const [
      "if (dart.library.html) 'pwa_install_service_web.dart'",
      'static Future<String> install()',
    ]);
    containsAll('lib/screens/pwa_install_screen.dart', const [
      "title: 'AppСтрой как приложение'",
      "'Установить приложение'",
      'PwaInstallService.manualInstruction',
    ]);
    containsAll('lib/screens/settings_screen.dart', const [
      'PwaInstallService.isSupported',
      "title: 'Установить AppСтрой'",
      'PwaInstallScreen',
    ]);
  });
}
