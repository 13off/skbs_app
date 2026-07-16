from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Ожидался один фрагмент в {path}, найдено: {count}')
    file_path.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/screens/pwa_install_screen.dart',
    'icon: Icons.auto_sync_rounded,',
    'icon: Icons.sync_rounded,',
)

Path('lib/services/pwa_install_service_web.dart').write_text(
    r'''import 'dart:js_interop';

@JS('appstroyIsPwaInstalled')
external JSBoolean _appstroyIsPwaInstalled();

@JS('appstroyCanInstallPwa')
external JSBoolean _appstroyCanInstallPwa();

@JS('appstroyInstallPwa')
external JSPromise<JSString> _appstroyInstallPwa();

@JS('appstroyUserAgent')
external JSString _appstroyUserAgent();

bool get isSupported => true;

bool get isInstalled {
  try {
    return _appstroyIsPwaInstalled().toDart;
  } catch (_) {
    return false;
  }
}

bool get canPrompt {
  try {
    return _appstroyCanInstallPwa().toDart;
  } catch (_) {
    return false;
  }
}

String get _userAgent {
  try {
    return _appstroyUserAgent().toDart.toLowerCase();
  } catch (_) {
    return '';
  }
}

String get platformName {
  final userAgent = _userAgent;
  if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
    return 'iPhone или iPad';
  }
  if (userAgent.contains('android')) return 'Android';
  if (userAgent.contains('windows')) return 'Windows';
  if (userAgent.contains('macintosh') || userAgent.contains('mac os')) {
    return 'Mac';
  }
  return 'устройстве';
}

String get manualInstruction {
  final userAgent = _userAgent;
  if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
    return 'Откройте AppСтрой в Safari, нажмите «Поделиться» и выберите «На экран Домой».';
  }
  if (userAgent.contains('android')) {
    return 'Откройте меню браузера и выберите «Установить приложение» или «Добавить на главный экран».';
  }
  if (userAgent.contains('edg/')) {
    return 'В Microsoft Edge откройте меню «…» → «Приложения» → «Установить AppСтрой».';
  }
  if (userAgent.contains('chrome/')) {
    return 'В Chrome нажмите значок установки справа в адресной строке или откройте меню → «Установить AppСтрой».';
  }
  if (userAgent.contains('safari/')) {
    return 'Откройте меню браузера и добавьте AppСтрой на рабочий стол или в Dock.';
  }
  return 'Откройте меню браузера и выберите установку сайта как приложения.';
}

Future<String> install() async {
  if (isInstalled) return 'installed';
  try {
    return (await _appstroyInstallPwa().toDart).toDart;
  } catch (_) {
    return 'unavailable';
  }
}
''',
    encoding='utf-8',
)

index_path = Path('web/index.html')
index_text = index_path.read_text(encoding='utf-8')
old_block = r'''      window.appstroyCanInstallPwa = function () {
        return Boolean(deferredPwaPrompt);
      };

      window.appstroyInstallPwa = async function () {
        var standalone = window.matchMedia('(display-mode: standalone)').matches ||
          window.navigator.standalone === true;
        if (standalone) {
          return { status: 'installed' };
        }
        if (!deferredPwaPrompt) {
          return { status: 'unavailable' };
        }

        var prompt = deferredPwaPrompt;
        deferredPwaPrompt = null;
        await prompt.prompt();
        var choice = await prompt.userChoice;
        return { status: choice && choice.outcome ? choice.outcome : 'dismissed' };
      };'''
new_block = r'''      window.appstroyIsPwaInstalled = function () {
        return window.matchMedia('(display-mode: standalone)').matches ||
          window.navigator.standalone === true;
      };

      window.appstroyCanInstallPwa = function () {
        return Boolean(deferredPwaPrompt);
      };

      window.appstroyUserAgent = function () {
        return window.navigator.userAgent || '';
      };

      window.appstroyInstallPwa = async function () {
        if (window.appstroyIsPwaInstalled()) {
          return 'installed';
        }
        if (!deferredPwaPrompt) {
          return 'unavailable';
        }

        var prompt = deferredPwaPrompt;
        deferredPwaPrompt = null;
        await prompt.prompt();
        var choice = await prompt.userChoice;
        return choice && choice.outcome ? choice.outcome : 'dismissed';
      };'''
if index_text.count(old_block) != 1:
    raise SystemExit('PWA JavaScript блок не совпал с ожидаемым')
index_path.write_text(index_text.replace(old_block, new_block, 1), encoding='utf-8')

Path('test/pwa_flutter_344_compat_contract_test.dart').write_text(
    r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('PWA bridge uses current Dart JS interop supported by Flutter 3.44', () {
    final service = source('lib/services/pwa_install_service_web.dart');
    expect(service, contains("import 'dart:js_interop';"));
    expect(service, isNot(contains("dart:js_util")));
    expect(service, isNot(contains("dart:html")));
    expect(service, contains('JSPromise<JSString>'));

    final index = source('web/index.html');
    expect(index, contains('appstroyIsPwaInstalled'));
    expect(index, contains('appstroyUserAgent'));
    expect(index, contains("return 'unavailable';"));

    final installScreen = source('lib/screens/pwa_install_screen.dart');
    expect(installScreen, contains('Icons.sync_rounded'));
    expect(installScreen, isNot(contains('Icons.auto_sync_rounded')));
  });
}
''',
    encoding='utf-8',
)
