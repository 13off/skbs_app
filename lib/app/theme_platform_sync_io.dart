import 'package:flutter/services.dart';

const MethodChannel _themeChannel = MethodChannel('ru.appstroy.skbs/theme');

Future<void> applyTheme({required bool isDark}) async {
  try {
    await _themeChannel.invokeMethod<void>('applyTheme', <String, bool>{
      'dark': isDark,
    });
  } on MissingPluginException {
    // На платформах без нативной реализации тема остаётся внутри Flutter.
  } catch (_) {
    // Смена иконки не должна блокировать основную тему приложения.
  }
}
