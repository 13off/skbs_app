import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PWA screen only offers real browser prompt and explains Yandex fallback',
    () {
      final screen = File(
        'lib/screens/pwa_install_screen.dart',
      ).readAsStringSync();
      final service = File(
        'lib/services/pwa_install_service_web.dart',
      ).readAsStringSync();
      final index = File('web/index.html').readAsStringSync();

      expect(index, contains('beforeinstallprompt'));
      expect(index, contains('appstroyInstallPwa'));
      expect(screen, contains('!canPrompt'));
      expect(screen, contains('Открыть в Edge'));
      expect(screen, contains('Скопировать адрес'));
      expect(service, contains("contains('yabrowser/')"));
      expect(service, contains('Яндекс.Браузер не всегда показывает'));
    },
  );
}
