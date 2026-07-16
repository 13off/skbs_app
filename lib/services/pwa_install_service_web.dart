import 'dart:html' as html;
import 'dart:js_util' as js_util;

bool get isSupported => true;

bool get isInstalled {
  try {
    if (html.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    final navigator = html.window.navigator;
    if (js_util.hasProperty(navigator, 'standalone')) {
      return js_util.getProperty<Object?>(navigator, 'standalone') == true;
    }
  } catch (_) {}
  return false;
}

bool get canPrompt {
  try {
    return js_util.callMethod<Object?>(
          html.window,
          'appstroyCanInstallPwa',
          const <Object?>[],
        ) ==
        true;
  } catch (_) {
    return false;
  }
}

String get platformName {
  final userAgent = html.window.navigator.userAgent.toLowerCase();
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
  final userAgent = html.window.navigator.userAgent.toLowerCase();
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
    final promise = js_util.callMethod<Object?>(
      html.window,
      'appstroyInstallPwa',
      const <Object?>[],
    );
    if (promise == null) return 'unavailable';
    final result = await js_util.promiseToFuture<Object?>(promise);
    if (result == null || !js_util.hasProperty(result, 'status')) {
      return 'unavailable';
    }
    return js_util.getProperty<Object?>(result, 'status')?.toString() ??
        'unavailable';
  } catch (_) {
    return 'unavailable';
  }
}
