import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:universal_html/html.dart' as html;

@JS('appstroyCanInstallPwa')
external JSBoolean _appstroyCanInstallPwa();

@JS('appstroyInstallPwa')
external JSPromise<JSObject> _appstroyInstallPwa();

bool get isSupported => true;

bool get isInstalled {
  try {
    return html.window.matchMedia('(display-mode: standalone)').matches;
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
    return html.window.navigator.userAgent.toLowerCase();
  } catch (_) {
    return '';
  }
}

String get browserName {
  final userAgent = _userAgent;
  if (userAgent.contains('yabrowser/')) return 'Яндекс.Браузер';
  if (userAgent.contains('edg/')) return 'Microsoft Edge';
  if (userAgent.contains('chrome/')) return 'Google Chrome';
  if (userAgent.contains('safari/')) return 'Safari';
  return 'браузер';
}

bool get isYandexBrowser => _userAgent.contains('yabrowser/');

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
  if (userAgent.contains('yabrowser/')) {
    return 'Яндекс.Браузер не всегда показывает системное окно установки. Для надёжной установки откройте эту же страницу в Microsoft Edge: меню «…» → «Приложения» → «Установить этот сайт как приложение».';
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
    final result = await _appstroyInstallPwa().toDart;
    return result.getProperty<JSString>('status'.toJS).toDart;
  } catch (_) {
    return 'unavailable';
  }
}
